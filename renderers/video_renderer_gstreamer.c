/**
 * RPiPlay - An open-source AirPlay mirroring server for Raspberry Pi
 * Copyright (C) 2019 Florian Draschbacher
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 */

#include "video_renderer.h"
#include <assert.h>
#include <gst/gst.h>
#include <gst/app/gstappsrc.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct video_renderer_gstreamer_s {
    video_renderer_t base;
    GstElement *appsrc, *pipeline, *sink;
} video_renderer_gstreamer_t;

static const video_renderer_funcs_t video_renderer_gstreamer_funcs;

static gboolean check_plugins(void)
{
    int i;
    gboolean ret;
    GstRegistry *registry;
    const gchar *needed[] = {"app", "libav", "playback", "autodetect", "videoparsersbad", NULL};

    registry = gst_registry_get();
    ret = TRUE;
    for (i = 0; i < g_strv_length((gchar **)needed); i++) {
        GstPlugin *plugin;
        plugin = gst_registry_find_plugin(registry, needed[i]);
        if (!plugin) {
            g_print("Required gstreamer plugin '%s' not found\n", needed[i]);
            ret = FALSE;
            continue;
        }
        gst_object_unref(plugin);
    }
    return ret;
}

video_renderer_t *video_renderer_gstreamer_init(logger_t *logger, video_renderer_config_t const *config) {
    video_renderer_gstreamer_t *renderer;
    GError *error = NULL;

    renderer = calloc(1, sizeof(video_renderer_gstreamer_t));
    assert(renderer);

    gst_init(NULL, NULL);

    renderer->base.logger = logger;
    renderer->base.funcs = &video_renderer_gstreamer_funcs;
    renderer->base.type = VIDEO_RENDERER_GSTREAMER;

    assert(check_plugins());

    // Begin the video pipeline - HARDCODED ROTATION
    GString *launch = g_string_new("appsrc name=video_source stream-type=0 format=GST_FORMAT_TIME is-live=true !"
                                   "queue ! decodebin ! videoconvert ! "
                                   "video/x-raw ! videoflip method=clockwise ! videoconvert ! ");

    // Setup flip - HARDCODED (uncomment the one you want)
    // g_string_append(launch, "videoflip method=horizontal-flip ! ");
    // g_string_append(launch, "videoflip method=vertical-flip ! ");
    // g_string_append(launch, "videoflip method=rotate-180 ! ");

    // Finish the pipeline (choose sink)
    const char *forced_sink = getenv("RPIPLAY_GST_SINK");
    if (forced_sink && forced_sink[0] != '\0') {
        g_string_append_printf(launch, "%s name=video_sink sync=false", forced_sink);
    } else {
        // If not running under X/Wayland, prefer a TTY-capable sink
        const char *x_display = getenv("DISPLAY");
        const char *wayland_display = getenv("WAYLAND_DISPLAY");
        if (!x_display && !wayland_display) {
            // On pure TTY, kmssink is typically the right choice. If unavailable, the pipeline will fail;
            // users can override with RPIPLAY_GST_SINK=fbdevsink device=/dev/fb0
            g_string_append(launch, "kmssink name=video_sink sync=false");
        } else {
            g_string_append(launch, "autovideosink name=video_sink sync=false");
        }
    }

    // Log the pipeline for debugging
    printf("*** USING GSTREAMER RENDERER WITH HARDCODED ROTATION ***\n");
    printf("GStreamer pipeline: %s\n", launch->str);
    
    renderer->pipeline = gst_parse_launch(launch->str, &error);
    if (!renderer->pipeline) {
        printf("Failed to create GStreamer pipeline: %s\n", error ? error->message : "Unknown error");
        if (error) g_error_free(error);
        g_string_free(launch, TRUE);
        free(renderer);
        return NULL;
    }
    g_string_free(launch, TRUE);

    renderer->appsrc = gst_bin_get_by_name(GST_BIN(renderer->pipeline), "video_source");
    renderer->sink = gst_bin_get_by_name(GST_BIN(renderer->pipeline), "video_sink");

    return &renderer->base;
}

static void video_renderer_gstreamer_start(video_renderer_t *renderer) {
    video_renderer_gstreamer_t *r = (video_renderer_gstreamer_t *)renderer;
    gst_element_set_state(r->pipeline, GST_STATE_PLAYING);
}

static void video_renderer_gstreamer_render_buffer(video_renderer_t *renderer, raop_ntp_t *ntp, unsigned char *data, int data_len, uint64_t pts, int type) {
    video_renderer_gstreamer_t *r = (video_renderer_gstreamer_t *)renderer;
    GstBuffer *buffer;

    assert(data_len != 0);

    buffer = gst_buffer_new_and_alloc(data_len);
    assert(buffer != NULL);
    GST_BUFFER_DTS(buffer) = (GstClockTime)pts;
    gst_buffer_fill(buffer, 0, data, data_len);
    gst_app_src_push_buffer(GST_APP_SRC(r->appsrc), buffer);
}

void video_renderer_gstreamer_flush(video_renderer_t *renderer) {

}

void video_renderer_gstreamer_destroy(video_renderer_t *renderer) {
    video_renderer_gstreamer_t *r = (video_renderer_gstreamer_t *)renderer;
    gst_app_src_end_of_stream(GST_APP_SRC(r->appsrc));
    gst_element_set_state(r->pipeline, GST_STATE_NULL);
    gst_object_unref(r->pipeline);
    if (renderer) {
        free(renderer);
    }
}

void video_renderer_gstreamer_update_background(video_renderer_t *renderer, int type) {

}

static const video_renderer_funcs_t video_renderer_gstreamer_funcs = {
    .start = video_renderer_gstreamer_start,
    .render_buffer = video_renderer_gstreamer_render_buffer,
    .flush = video_renderer_gstreamer_flush,
    .destroy = video_renderer_gstreamer_destroy,
    .update_background = video_renderer_gstreamer_update_background,
};
