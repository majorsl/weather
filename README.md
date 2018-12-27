# weather
Kludgy weather in html with single image options.

NOTE: This is now defunct. Wunderground has discontinued it's free api. If you have your own weather-station, and upload data to them, this may still be useful to display it. I have another repository with a Ubersicht widget that also displays weather info and still works using the data from DarkSky, if you're interested.

This is a project that I started sometime around 2010, a time when I just starting to learn a little shell scripting. It started as pure html in an attempt to put a weather widget on a web page. It was simple and low-key.

Over time, I addeed more and more to it. It became kludgy, messy and ugly and is probably a good example of feature creep with items bolted on over time.

But, it still works. Now that it is here, I plan to work on it more and get it cleaned up and probably a code refactoring is very much in order. Enjoy it "as is" with the follow notes on how it works.

1 - it gets it's data from Wunderground, so you'll need to go over there and get an api key. It uses the standard weather, forecastconditions, astronomy, forecast7day, alerts, almanac, & hourly conditions. Make sure you include that in your preferences for wunderground.

2 - getweather.sh gets the weather data and parses it, creating the html documents that assemble the weather widget. It does this by symlinking various weather images that match the conditions in the weather data, along with writing text strings to texts files.

3 - apache (or your favorite web-server) needs to have follow symlinks and server-side includes (SSI) enabled. Your server will read the wheather.shtml or blogweather.shtml (the two default modes I have created) and assemble a layout based on those images and text data using css, SSI, and html.

4 - Using wkhtmltoimage which is part of https://wkhtmltopdf.org/, I generate some jpgs that can be used with various programs as widgets on desktops or as images in webpages.

5 - see the example launchd to run the getweather.sh script every 30 minutes to update. You can, of course, use cron or some other timer too.

6 - It also uses Apple's Notification Center to display notices for updates. You'll need https://github.com/julienXX/terminal-notifier for this.
