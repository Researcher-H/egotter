::S3.class
::S3::Util.class
::S3::Querying.class
::S3::Api.class
::S3::Friendship.class
::S3::Followership.class
::S3::ProfileApi.class
::S3::Profile.class
::S3::Friendship.client
::S3::Followership.client
::S3::Profile.client

::DynamoDB.class
::DynamoDB::Util.class
::DynamoDB::TwitterUser.class
::DynamoDB::Client.class
::DynamoDB::Client.dynamo_db

::Efs.class
::Efs::TwitterUser.class
::Efs::TwitterUser.cache_client unless Rails.env.test? # For database creation on TravisCI
::Efs::Tweet.class
::Efs::StatusTweet.class
::Efs::FavoriteTweet.class
::Efs::MentionTweet.class

::InMemory.class
::InMemory::Tweet.class
::InMemory::StatusTweet.class

# Avoid `uninitialized constant` or `Unable to autoload constant`
::TwitterUser
::TwitterDB::User
::Api::V1
