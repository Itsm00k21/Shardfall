#!/bin/sh
# Lune lock for the six-button rail smoke. The Studio pass is play.luau,
# pasted into the client command bar while the place is playing.
cd "$(dirname "$0")/../.." || exit 1
exec lune run ops/studio-smoke/run
