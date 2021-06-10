mpv-notify
==========

Adds desktop notifications to the [mpv](http://mpv.io) media player, which show
metadata like artist, album name and track name when the track changes.

Features
--------

* shows artist, title and album name (as far as detected by mpv)
* extracts cover art using ffmpeg
* writes icon, artist, album, title to temporary files (useful for OBS)

Requirements
------------

* [mpv](http://mpv.io) (>= 0.3.6)
* [Lua](http://lua.org) (>= 5.2)
* `ffmpeg` from [https://www.ffmpeg.org/](https://www.ffmpeg.org/)
* `ffmpegthumbnailer` from [ffmpegthumbnailer](https://github.com/dirkvdb/ffmpegthumbnailer) `(optional only for video thumbnails)`
* `notify-send` from [libnotify](https://github.com/GNOME/libnotify)
* `convert` from [ImageMagick](http://www.imagemagick.org)

Install mpv, lua, ffmpeg, ffmpegthumbnailer(optionl), libnotify and ImageMagick packages

Installation
------------

Just drop `notify.lua` into the folder `~/.config/scripts/lua` (create it when neccessary),
and mpv will find it. Optionally, you can add it to mpv's command line:

    mpv --lua=/path/to/notify.lua <files and options>

License
-------

mpv-notify was originally written by Roland Hieber <rohieb at rohieb.name>. I have simply
refactored it according to my needs. You may use it under the terms of the
[MIT license](http://choosealicense.com/licenses/mit/).
