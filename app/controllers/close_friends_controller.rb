class CloseFriendsController < GoodFriends
  include CloseFriendsHelper

  def all
    super
    render template: 'friends/all'
  end

  def show
    super
  end
end
