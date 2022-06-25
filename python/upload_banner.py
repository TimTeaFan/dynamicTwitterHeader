import os
import tweepy

# Get environment variables
CONKEY = os.getenv('TIMTEAFAN_TWITTER_CONSUMER_API_KEY')
CONSEC = os.environ.get('TIMTEAFAN_TWITTER_CONSUMER_API_SECRET')
ACCKEY = os.getenv('TIMTEAFAN_TWITTER_ACCESS_TOKEN')
ACCSEC = os.environ.get('TIMTEAFAN_TWITTER_ACCESS_TOKEN_SECRET')

auth = tweepy.OAuth1UserHandler(
   CONKEY,
   CONSEC,
   ACCKEY,
   ACCSEC
)

api = tweepy.API(auth)

api.update_profile_banner('data/final_plot.png')