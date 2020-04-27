# Icecast Setup and Configuration Notes

## About
[Icecast](https://icecast.org/) is a media streaming relay server that runs on an HTTP based
protocol.  In a nutshell, it consists the server, source clients that stream media to the server,
and listener clients that stream media down from the server to play it. There's also a web interface
to view information about the current streams (called "mountpoints") and active listeners.

I'm not here to explain the full features or configuration of Icecast, there's plenty of
documentation for that already. Instead, this repo is to document the rabbit hole I fell down trying
to host an Icecast server behind nginx as a reverse proxy, and successfully streaming to it using
ffmpeg, curl, and OBS as source clients.

## Icecast Protocol
In a nutshell, source clients make an HTTP/1.1 PUT request for the mountpoint using HTTP basic
authentication and streams the media data in realtime as the body of the request. The source client
must set the Content-Type request header appropriately or Icecast will ignore the source. There's
also some metadata headers, but they're optional.

In Icecast version 2.4 (the latest stable release), source clients send an `Expect: 100-continue`
header and the server replies with an `HTTP/1.1 100 Continue` response before the actual media
streaming data starts.

The latest master branch of [icecast-server](https://gitlab.xiph.org/xiph/icecast-server) adds
support for the chunked transfer encoding method, by sending a `Transfer-Encoding: chunked` header
in the request, and _not_ using `Expect: 100-continue`. I'm not sure if this is a bug or not, but
I couldn't get chunked encoding to work along with expect 100.

### Reverse Proxy Difficulties
I run several internet-facing services using nginx as a reverse proxy to add TLS using a common set
of Letsencrypt certificates, so naturally it made sense to try doing the same for Icecast. Sounds
easy, right? Just put a HTTP service behind a popular HTTP reverse proxy. How hard could it be? As
it turns out, very hard.

Take it from TBR, a maintainer of Icecast: _"[tl;dr - Don't reverse proxy Icecast
](https://stackoverflow.com/questions/51786404/icecast2-running-under-nginx-not-able-to-connect/51786791#51786791)...
It is a purpose built HTTP server and generic HTTP servers tend to have siginificant issues with the
intracies of continuous HTTP streaming."_

As a reverse proxy, nginx wants to buffer both requests and responses, and it gets confused when the
body of an HTTP request has a content length of 0 and a potentially infinite connection time.

It's also worth noting that Icecast expects to be running from the root of the web server, not
a subdirectory. There's absolute URLs in the web UI pages and they'll break if you try to host
Icecast at something like https://example.com/icecast/. If you're adventurous and need to use
a subdirectory rather than a subdomain, there's some suggestions on stackoverflow for using
`rewrite` directives to change the links to work in a subdirectory. Or I guess you could patch the
Icecast server code.

The xiph wiki has some more notes on [known reverse proxy
restrictions](https://wiki.xiph.org/Icecast_Server/known_reverse_proxy_restrictions)

If you don't want to jump through all of these hoops, just don't run Icecast server through a proxy.
It has some built-in support for TLS if you don't mind configuring your certificates in icecast.xml.

## Icecast Behind Nginx
First, the hard truth: **don't even think about reverse-proxying Icecast v2.4.x. You need to build
the latest master branch from source.** The tip of the master branch at the time of writing (commit
2ffaa92ea656e40810e8f86174acf4d2fdd3219b) worked for me. The main reason behind this is that the
chunked transfer encoding is required for nginx to be able to comprehend and correctly forward the
"infinite" length.

### Core Nginx Config
The following is a nginx config _snippet_ for a `server` block that I'm using to run Icecast. Adding
this to a full nginx.conf file is an exercise left to the reader.

```nginx
http {
    # all the normal nginx options you're using for your server, such as logs, default MIME types,
    # TCP configuration, etc.

    # Put your SSL configuration here. Use something like the Mozilla SSL Configuration Generator
    # to set up a good modern configuration: https://ssl-config.mozilla.org/
    ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;

    server {
        listen 443 ssl http2;
        server_name icecast.example.com;

        location / {
            # Proxy everything the Icecast server's IP address (or hostname) and port.
            proxy_pass http://127.0.0.1:8000;

            # Disable request size limit, very important for uploading large files
            client_max_body_size 0;

            # Enable support `Transfer-Encoding: chunked`
            chunked_transfer_encoding on;

            # Disable request and response buffering, minimize latency to/from Icecast
            proxy_buffering off;
            proxy_request_buffering off;

            # Icecast needs HTTP/1.1, not 1.0 or 2
            proxy_http_version 1.1;

            # Forward all original request headers
            proxy_pass_request_headers on;

            # Set some standard reverse proxy headers. Icecast server currently ignores these,
            # but may support them in a future version so that access logs are more useful.
            proxy_set_header  Host              $http_host;
            proxy_set_header  X-Real-IP         $remote_addr;
            proxy_set_header  X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header  X-Forwarded-Proto $scheme;
        }
    }
}
```

### Extra Nginx Config
To further enhance the security for internet-facing instances, consider:

  * Restricting the /admin location to certain IP addresses to block it from being accessible from
    the internet.
  * Adding authentication for listener clients (which receive streams using the GET method)

I haven't done these yet, but will update this page if/when I get around to it.

## Icecast Source Clients
I'm focused on [ffmpeg](https://ffmpeg.org/) as my source client, since I'm already comfortable with
using ffmpeg as a flexible media transcoder.

It's important that the source client sends the data to Icecast in real time. This is easy for
content that's generated in realtime (such as the output of OBS), but adds complications for
streaming existing media files on disc. The source client can't just send data to the server as fast
as the network allows, and the server doesn't have a mechanism to tell a source client to slow down,
the client has to be able to rate-limit itself. When using ffmpeg, the `realtime` or `arealtime`
filters can be added to the filter chain to ensure 1x output speed (as long as transcoding can keep
up).

The source client should also set the Content-Type header appropriately with the MIME type of what
it's streaming. Icecast formally supports vorbis/opus in an OGG container as `application/ogg` or
WebM (matroska) containers as `video/webm`. Other container formats (such as `video/m2ts` for
a MPEG-TS stream) will be blindly passed on by Icecast without any special decoding or treatment.

### FFmpeg

FFmpeg has an [icecast protocol](https://ffmpeg.org/ffmpeg-protocols.html#Icecast) built-in, which
is really just a [thin wrapper](https://github.com/FFmpeg/FFmpeg/blob/master/libavformat/icecast.c)
over the http protocol. The icecast protocol in ffmpeg will send a PUT request with an `Expect:
100-continue` header and chunked transfer encoding disabled.  That's not what we want for proxying
the latest versions of Icecast.

Fortunately, we can use ffmpeg's http or https protocols to stream to icecast with some options.
The important protocol options to set are:

  * `-f format`: when outputting to a URL, you must tell ffmpeg what container format (muxer) to
    use, it should match whatever content you're streaming as well as the content type header.
  * `-content_type type/subtype`: set the appropriate MIME type for the container format.
  * `-method PUT`: upload data with a PUT request rather than POST.
  * `-auth_type basic`: use HTTP basic authentication. The source username/password go into the URL
    itself.
  * `-chunked_post 1`: use chunked transfer encoding.
  * `-send_expect_100 0`: don't send an `Expect: 100-continue` header, as this confuses Icecast when
    combined with chunked transfer encoding.
  * Specify the URL in the form https://user:password@server[:port]/mountpoint.extension

Here's some example ffmpeg commands. Note that the general structure of an ffmpeg command line is
`ffmpeg -i <input file> <stream mapping> <codec and filters> <output format> <output options>
<protocol options> <output file/URL>`

```sh
# Transcode a FLAC file to opus
ffmpeg -i input.flac -vn -c:a libopus -b:a 256k -af arealtime -f ogg -content_type application/ogg \
    -method PUT -auth_type basic -chunked_post 1 -send_expect_100 0 \
    https://source:hackme@icecast.example.com/audio.opus

# Stream an H.264+AAC video file as MPEG-TS, transcoding audio to use the arealtime filter
ffmpeg -i input.mp4 -c:v copy -c:a aac -b:a 256k -af arealtime -f mpegts -content_type video/m2ts \
    -method PUT -auth_type basic -chunked_post 1 -send_expect_100 0 \
    https://source:hackme@icecast.example.com/video.ts

# webm video sucks because VP8/VP9 require a ton of CPU power to be able to encode in real-time.
# Here's a VAPPI hardware encode example, or you can use the copy codec of an existing VP9 video.
ffmpeg -i input.mp4 -c:a libopus -b:a 160k -af arealtime \
    -vaapi_device /dev/dri/renderD128 -vf 'format=nv12,hwupload' -c:v vp9_vaapi -b:v 5M \
    -f webm -content_type video/webm -method PUT -auth_type basic -chunked_post 1 -send_expect_100 0 \
    https://source:hackme@icecast.example.com/video.webm

# Advanced: use copy codec for video and audio, and add a second null output for realtime limiting
# This is totally a hack/workaround, but it seems to be functional without too much extra overhead
ffmpeg -i input.mp4 -map 0:v:0 -map 0:a:0 -c:v copy -c:a copy -f mpegts -content_type video/m2ts \
    -method PUT -auth_type basic -chunked_post 1 -send_expect_100 0 \
    https://source:hackme@icecast.example.com/video.ts \
    -map 0:a:0 -c:a pcm_s8 -af arealtime -f s8 -y /dev/null
```

### OBS Studio
The popular OBS streaming software can also stream to Icecast by (ab)using a custom ffmpeg recording
output. I got started using [this guide](https://epir.at/2018/03/08/obs-icecast-streaming/).

I've had the best results using the mpegts container with libx264 video and aac audio. webm with
VP8/VP9 and libvorbis/libopus should work in theory, but they make OBS crash for me on Windows. YMMV.

  1. Go to the Output tab of the settings
  2. In the Output Mode dropdown, choose Advanced
  3. Change Type to "Custom Output (FFmpeg)
  4. Change FFmpeg Output Type to "Output to URL"
  5. For "File path or URL" use the same URL format as the ffmpege examples,
     https://source:hackme@icecast.exmple.com/mountpoint.ts
  6. Set Container Format to mpegts
  7. Put all the protocol options into "Muxer Settings (if any)" but in "key=value" format rather
     than "-key value" as seen in ffmpeg command line options: `content_type=video/m2ts method=PUT
     auth_type=basic chunked_post=1`
  8. Check the "show all codecs" box and pick libx264 as the video encoder. Add `preset=slow` for
     better quality in Video Encoder Settings, if your CPU can handle it.
  9. Select aac as the Audio Encoder
 10. Select appropriate video and audio bitrates

![OBS Settings Screenshot](OBS_icecast_settings.png)

Note that this sets up Icecast output as a Recording in OBS, not as the Stream output. Therefore, to
start streaming you need to use "Start Recording" rather than "Start Streaming".
