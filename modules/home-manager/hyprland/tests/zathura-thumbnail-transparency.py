"""Check Zathura's actual thumbnail creation and drawing code with Cairo."""

import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile


source = Path(sys.argv[1]).read_text()


def function(signature):
    start = source.index(signature + " {")
    end = source.index("\n}", start) + 2
    return source[start:end]


draw_start = source.index(
    "cairo_scale(cairo, pwidth / (double)width, pheight / (double)height);"
)
draw_end = source.index("cairo_restore(cairo);", draw_start)
draw = source[draw_start:draw_end]

test = r"""
#include <cairo.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
typedef struct { double x, y; } zathura_device_factors_t;
#define THUMBNAIL_INITIAL_ZOOM 0.5
#define THUMBNAIL_MAX_ZOOM 0.5
"""
test += function(
    "static zathura_device_factors_t get_safe_device_factors(cairo_surface_t* surface)"
)
test += "\n" + function(
    "static cairo_surface_t* draw_thumbnail_image(cairo_surface_t* surface, size_t max_size)"
)
test += r"""
static uint32_t pixel(cairo_surface_t* surface) {
  cairo_surface_flush(surface);
  return *(uint32_t*)cairo_image_surface_get_data(surface);
}

int main(void) {
  const double alphas[] = {0.0, 0.4, 1.0};
  for (unsigned int i = 0; i < 3; ++i) {
    cairo_surface_t* page = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 32, 32);
    cairo_t* cr = cairo_create(page);
    cairo_set_source_rgba(cr, 0.8, 0.6, 0.4, alphas[i]);
    cairo_paint(cr);
    cairo_destroy(cr);
    cairo_surface_t* thumbnail = draw_thumbnail_image(page, 256);
    cairo_surface_t* reference = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 32, 32);
    cairo_surface_t* preview = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 32, 32);
    cairo_surface_t* targets[] = {reference, preview};
    for (unsigned int target = 0; target < 2; ++target) {
      cairo_t* cairo = cairo_create(targets[target]);
      cairo_set_source_rgba(cairo, 0.3, 0.1, 0.2, 0.8);
      cairo_paint(cairo);
      if (target == 0) {
        cairo_set_source_surface(cairo, page, 0, 0);
        cairo_paint(cairo);
      } else {
        unsigned int width = cairo_image_surface_get_width(thumbnail);
        unsigned int height = cairo_image_surface_get_height(thumbnail);
        unsigned int pwidth = 32, pheight = 32;
        struct { cairo_surface_t* thumbnail; } holder = {thumbnail}, *priv = &holder;
"""
test += draw
test += r"""
      }
      cairo_destroy(cairo);
    }
    uint32_t expected = pixel(reference), actual = pixel(preview);
    printf("alpha %.1f: reference=%08x thumbnail=%08x\n", alphas[i], expected, actual);
    cairo_surface_destroy(preview);
    cairo_surface_destroy(reference);
    cairo_surface_destroy(thumbnail);
    cairo_surface_destroy(page);
    if (actual != expected) return 1;
  }
  return 0;
}
"""

flags = os.environ.get("ZATHURA_TEST_CFLAGS")
if flags is None:
    flags = subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "cairo"], text=True
    )
with tempfile.TemporaryDirectory(prefix="zathura-thumbnail-test-") as directory:
    path = Path(directory)
    (path / "test.c").write_text(test)
    subprocess.run(
        shlex.split(os.environ.get("CC", "cc"))
        + [str(path / "test.c"), "-o", str(path / "test")]
        + shlex.split(flags)
        + ["-lm"],
        check=True,
    )
    subprocess.run([str(path / "test")], check=True)
