class TwitterUserDecorator < ApplicationDecorator
  delegate_all

  def delimited_statuses_count
    statuses_count.to_i.to_s(:delimited)
  end

  def delimited_friends_count
    friends_count.to_i.to_s(:delimited)
  end

  def delimited_followers_count
    followers_count.to_i.to_s(:delimited)
  end

  def status_interval_avg_in_words
    if status_interval_avg == 0
      0
    else
      h.time_ago_in_words(Time.zone.now - status_interval_avg) rescue nil
    end
  end

  def percent_follow_back_rate
    h.number_to_percentage(follow_back_rate * 100, precision: 1) rescue nil
  end

  def reverse_percent_follow_back_rate
    h.number_to_percentage(reverse_follow_back_rate * 100, precision: 1) rescue nil
  end

  def account_created_at?
    account_created_at.present? && !account_created_at.kind_of?(String)
  end

  def location?
    location.present?
  end

  def url?
    url.present?
  end

  def description?
    description.present?
  end

  def profile_icon_url?
    profile_image_url_https.present?
  end

  def profile_icon_url_for(request)
    profile_image_url_https.remove('_normal')
  end

  def profile_banner_url?
    profile_banner_url.present?
  end

  def profile_banner_url_for(request)
    # suffix = request.from_pc? ? 'web_retina' : 'mobile_retina'
    suffix = '1080x360'
    "#{profile_banner_url}/#{suffix}"
  end

  def profile_link_color_code
    "##{profile_link_color}"
  end

  def suspended_label
    if suspended?
      h.tag.span(class: 'badge badge-danger') { I18n.t('twitter.profile.labels.suspended') }
    end
  end

  def blocked_label
    if blocked?
      h.tag.span(class: 'badge badge-secondary') { I18n.t('twitter.profile.labels.blocked') }
    end
  end

  def inactive_label
    if !suspended? && inactive?
      h.tag.span(class: 'badge badge-secondary') { I18n.t('twitter.profile.labels.inactive') }
    end
  end

  def refollow_label
    if refollow?
      h.tag.span(class: 'badge badge-info') { I18n.t('twitter.profile.labels.refollow') }
    end
  end

  def refollowed_label
    if refollowed?
      h.tag.span(class: 'badge badge-info') { I18n.t('twitter.profile.labels.refollowed') }
    end
  end

  def followed_label
    h.tag.span(class: 'badge badge-secondary') { I18n.t('twitter.profile.labels.followed') }
  end

  def status_labels
    [
        suspended_label,
        blocked_label,
        inactive_label,
        refollow_label,
        refollowed_label,
    ].compact.join('&nbsp;').html_safe
  end

  def single_followed_label
    h.tag.span(class: 'text-muted small') do |tag|
      tag.i(class: 'fas fa-user') + '&nbsp;'.html_safe + I18n.t('twitter.profile.labels.followed')
    end
  end

  def protected_icon
    if protected?
      h.tag.i(class: 'fas fa-lock text-warning')
    end
  end

  def verified_icon
    if verified?
      h.tag.i(class: 'fas fa-check text-primary')
    end
  end

  def name_with_icon
    [
        name,
        protected_icon,
        verified_icon
    ].compact.join('&nbsp;').html_safe
  end

  def to_param
    screen_name
  end

  def suspended?
    if context.has_key?(:suspended_uids)
      context[:suspended_uids].include?(uid)
    else
      object.suspended
    end
  end

  def blocked?
    if context.has_key?(:blocking_uids)
      context[:blocking_uids].include?(uid)
    end
  end

  def updated
    if object.updated_at > 1.hour.ago
      text = h.time_ago_in_words(object.updated_at)
    else
      text = I18n.l(object.updated_at.in_time_zone('Tokyo'), format: :profile_header_long)
    end
    I18n.t('twitter.profile.updated_at', text: text)
  end

  private

  def refollow?
    if context.has_key?(:friend_uids)
      context[:friend_uids].include?(uid)
    end
  end

  def refollowed?
    if context.has_key?(:follower_uids)
      context[:follower_uids].include?(uid)
    end
  end

  def inactive?
    if object.respond_to?(:inactive?)
      object.inactive?
    elsif object.respond_to?(:status)
      status&.created_at && Time.parse(status.created_at) < 2.weeks.ago
    end
  end

  def protected?
    object.protected
  end

  def verified?
    verified
  end
end
