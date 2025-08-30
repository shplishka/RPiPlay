#!/bin/bash

echo "=== Testing Different Video Sinks for Rotation ==="

# Test different GStreamer video sinks to see which handles rotation best
sinks=("autovideosink" "xvimagesink" "ximagesink" "waylandsink" "kmssink" "fbdevsink")

for sink in "${sinks[@]}"; do
    echo ""
    echo "Testing sink: $sink"
    echo "Command: gst-launch-1.0 -v videotestsrc pattern=smpte num-buffers=30 ! rotate angle=1.5708 ! videoconvert ! $sink sync=false"
    
    # Test if the sink is available
    if gst-inspect-1.0 "$sink" &> /dev/null; then
        echo "✓ $sink is available"
        
        # Try a quick test (3 seconds)
        timeout 3 gst-launch-1.0 -q videotestsrc pattern=smpte num-buffers=30 ! rotate angle=1.5708 ! videoconvert ! "$sink" sync=false &> /dev/null
        
        if [ $? -eq 0 ]; then
            echo "✓ $sink works with rotation"
            echo "   You can force this sink with: export RPIPLAY_GST_SINK='$sink'"
        else
            echo "✗ $sink has issues with rotation"
        fi
    else
        echo "✗ $sink not available"
    fi
done

echo ""
echo "=== Testing RPiPlay with different sinks ==="
echo "You can test RPiPlay with specific sinks using:"
echo "export RPIPLAY_GST_SINK='xvimagesink fullscreen=true'"
echo "./rpiplay -vr gstreamer"
echo ""
echo "Or try:"
echo "export RPIPLAY_GST_SINK='kmssink fullscreen=true'"
echo "./rpiplay -vr gstreamer"
