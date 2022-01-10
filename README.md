# nplay

I'm using shortcut for mpv to play online videos via [yt-dlp](https://github.com/yt-dlp/yt-dlp).
Sometimes it takes several seconds before video actually starts playing. This application is intended
to solve several problems:

1. Show notification until player displays X11 window.
2. Clicking that notification kills player if it hasn't created any windows yet.
3. Some videos are broken in certain formats, error popup will allow restarting player with another quality (mpv only).

# Usage
```
nplay /usr/bin/mpv player-options-and-url-to-play
```
