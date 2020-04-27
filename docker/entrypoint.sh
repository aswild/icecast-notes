#!/bin/sh
# Icecast server docker entrypoint script. Sets up important icecast.xml
# options from environment variables.
# Taken from https://github.com/infiniteproject/icecast
#
# Copyright (c) 2016 Ruggero <infiniteproject@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [ -n "$ICECAST_SOURCE_PASSWORD" ]; then
    sed -i "s/<source-password>[^<]*<\/source-password>/<source-password>$ICECAST_SOURCE_PASSWORD<\/source-password>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_RELAY_PASSWORD" ]; then
    sed -i "s/<relay-password>[^<]*<\/relay-password>/<relay-password>$ICECAST_RELAY_PASSWORD<\/relay-password>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_ADMIN_PASSWORD" ]; then
    sed -i "s/<admin-password>[^<]*<\/admin-password>/<admin-password>$ICECAST_ADMIN_PASSWORD<\/admin-password>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_ADMIN_USERNAME" ]; then
    sed -i "s/<admin-user>[^<]*<\/admin-user>/<admin-user>$ICECAST_ADMIN_USERNAME<\/admin-user>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_ADMIN_EMAIL" ]; then
    sed -i "s/<admin>[^<]*<\/admin>/<admin>$ICECAST_ADMIN_EMAIL<\/admin>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_LOCATION" ]; then
    sed -i "s/<location>[^<]*<\/location>/<location>$ICECAST_LOCATION<\/location>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_HOSTNAME" ]; then
    sed -i "s/<hostname>[^<]*<\/hostname>/<hostname>$ICECAST_HOSTNAME<\/hostname>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_MAX_CLIENTS" ]; then
    sed -i "s/<clients>[^<]*<\/clients>/<clients>$ICECAST_MAX_CLIENTS<\/clients>/g" /etc/icecast.xml
fi
if [ -n "$ICECAST_MAX_SOURCES" ]; then
    sed -i "s/<sources>[^<]*<\/sources>/<sources>$ICECAST_MAX_SOURCES<\/sources>/g" /etc/icecast.xml
fi

exec "$@"
