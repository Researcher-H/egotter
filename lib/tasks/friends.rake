namespace :friends do
  desc 'add user_info_gzip'
  task add_user_info_gzip: :environment do
    ActiveRecord::Base.connection.execute('ALTER TABLE friends ADD user_info_gzip BLOB NOT NULL AFTER user_info')
  end

  desc 'compress user_info'
  task compress_user_info: :environment do
    Friend.find_in_batches(batch_size: 1000) do |friends_array|
      friends = friends_array.map do |f|
        [f.id, '', '', '', ActiveSupport::Gzip.compress(f.user_info), 0]
      end
      Friend.import(%i(id uid screen_name user_info user_info_gzip from_id), friends, on_duplicate_key_update: %i(user_info_gzip), validate: false)
    end
  end

  desc 'remove user_info'
  task remove_user_info: :environment do
    Friend.find_in_batches(batch_size: 1000) do |friends_array|
      friends = friends_array.map do |f|
        [f.id, '', '', '', '', 0]
      end
      Friend.import(%i(id uid screen_name user_info user_info_gzip from_id), friends, on_duplicate_key_update: %i(user_info), validate: false)
    end
  end

  desc 'reset'
  task reset: :environment do
    ActiveRecord::Base.connection.execute('DROP TABLE IF EXISTS tmp_friends')
    ActiveRecord::Base.connection.execute('CREATE TABLE tmp_friends like friends')
    ActiveRecord::Base.connection.execute('ALTER TABLE tmp_friends ADD user_info_gzip BLOB NOT NULL AFTER user_info')
    ActiveRecord::Base.connection.execute('ALTER TABLE tmp_friends DROP user_info')
    ActiveRecord::Base.connection.execute('ALTER TABLE tmp_friends DROP updated_at')
    # ActiveRecord::Base.connection.execute('ALTER TABLE tmp_friends CHANGE id id INT(11) NOT NULL')
  end

  desc 'rename'
  task rename: :environment do
    ActiveRecord::Base.connection.execute('ALTER TABLE friends RENAME old_friends')
    ActiveRecord::Base.connection.execute('ALTER TABLE tmp_friends RENAME friends')
  end

  desc 'import'
  task import: :environment do
    sigint = false
    Signal.trap 'INT' do
      puts 'intercept INT and stop ..'
      sigint = true
    end

    start = ENV['START'].present? ? ENV['START'] : 1
    start_time = Time.zone.now
    failed = false

    Rails.logger.silence do
      Friend.find_in_batches(start: start, batch_size: 5000) do |friends_array|
        friends = friends_array.map do |f|
          [f.id, f.uid, f.screen_name, ActiveSupport::Gzip.compress(f.user_info), f.from_id, f.created_at]
        end

        begin
          TmpFriend.import(%i(id uid screen_name user_info_gzip from_id created_at), friends, validate: false)
          puts "#{Time.zone.now}: #{friends.first[0]} - #{friends.last[0]}"
        rescue => e
          puts "#{e.class} #{e.message.slice(0, 100)}"
          failed = true
        end

        break if sigint || failed
      end
    end

    puts (sigint || failed ? 'suspended:' : 'finished:')
    puts "  start: #{start}, #{(Time.zone.now - start_time)} seconds"
  end

  desc 'verify'
  task verify: :environment do
    Rails.logger.silence do
      num = ENV['NUM'].nil? ? 1000 : ENV['NUM'].to_i
      max = ENV['MAX'].nil? ? 1000 : ENV['MAX'].to_i
      min = ENV['MIN'].nil? ? 1 : ENV['MIN'].to_i
      rnd = ENV['RND'].nil? ? false : true
      slice_size = ENV['SLICE'].nil? ? 1000 : ENV['SLICE'].to_i
      ids =
        if rnd
          random = Random.new; range = min..max
          num.times.map { random.rand(range) }.uniq
        else
          (min..max).to_a.slice(0, num)
        end

      sql = <<-"SQL".strip_heredoc
        SELECT a.id
        FROM (
          SELECT id, uid, screen_name, from_id, created_at FROM friends WHERE id IN (:ids)
        ) a JOIN (
          SELECT id, uid, screen_name, from_id, created_at FROM tmp_friends WHERE id IN (:ids)
        ) b ON (a.id = b.id)
        WHERE a.uid = b.uid AND a.screen_name = b.screen_name AND a.from_id = b.from_id AND a.created_at = b.created_at
      SQL

      match_count = 0
      not_match_ids = []
      begin
        ids.each_slice(slice_size).each do |ids_array|
          matched_ids = Friend.find_by_sql([sql, ids: ids_array]).map(&:id)
          not_match_ids += (ids_array - matched_ids) if (ids_array - matched_ids).any?
          match_count += matched_ids.size
          print '.'
        end
        puts ''
      rescue => e
        puts "#{e.class} #{e.message.slice(0, 100)}"
      end

      user_info_match_count = 0
      begin
        (ids - not_match_ids).sample(slice_size).each do |id|
          result = Friend.find(id).user_info == ActiveSupport::Gzip.decompress(TmpFriend.find(id).user_info_gzip)
          user_info_match_count += 1 if result
          print '.'
        end
        puts ''
      rescue => e
        puts "#{e.class} #{e.message.slice(0, 100)}"
      end

      sql = <<-"SQL".strip_heredoc
        SELECT auto_increment at
        FROM information_schema.tables
        WHERE table_schema = "egotter_#{Rails.env}" AND table_name = :table
      SQL

      puts ''
      puts 'Summary:'
      puts "  num: #{num}, min: #{min}, max: #{max}, rnd: #{rnd}, slice: #{slice_size}, uniq_id: #{ids.size}, match: #{match_count} user_info_match(#{slice_size}): #{user_info_match_count}, id_min: #{ids.min}, id_max: #{ids.max}"
      puts 'Friend:'
      puts "  id_max: #{Friend.all.maximum(:id)}, auto_increment: #{Friend.find_by_sql([sql, table: :friends]).first.at}, match: #{Friend.where(id: ids).count}"
      puts 'TmpFriend:'
      puts "  id_max: #{TmpFriend.all.maximum(:id)}, auto_increment: #{Friend.find_by_sql([sql, table: :tmp_friends]).first.at}, match: #{TmpFriend.where(id: ids).count}"
      if not_match_ids.any?
        puts 'not match:'
        puts "  size: #{not_match_ids.size}, ids: #{not_match_ids.slice(0, 100).join(', ')}"
      end

      File.write("#{Rails.root}/ids.txt", ids.sort.join("\n"))
    end
  end
end