/* Shared setup for the ImageMagick6 libFuzzer harnesses. Bytes come only from the fuzzer; no file I/O. */
#ifndef MAYHEM_HARNESS_COMMON_H
#define MAYHEM_HARNESS_COMMON_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <magick/MagickCore.h>

/* Resource limits set through the public API, the way an embedder would; no wall-clock limits. */
static void mayhem_init(void)
{
  static int done;
  if (done)
    return;
  done = 1;
  MagickCoreGenesis(NULL, MagickFalse);
  (void) SetMagickResourceLimit(WidthResource, 8192);
  (void) SetMagickResourceLimit(HeightResource, 8192);
  (void) SetMagickResourceLimit(AreaResource, 128UL << 20);
  (void) SetMagickResourceLimit(MemoryResource, 256UL << 20);
  (void) SetMagickResourceLimit(MapResource, 0);
  (void) SetMagickResourceLimit(DiskResource, 0);
  (void) SetMagickResourceLimit(ThreadResource, 1);
}

/* Decode a blob. format == NULL sniffs the format from the magic bytes. */
static Image *mayhem_read(const uint8_t *data, size_t size, const char *format, ExceptionInfo *exception)
{
  ImageInfo *info = AcquireImageInfo();
  Image *image;
  if (format != NULL)
    (void) CopyMagickString(info->magick, format, MaxTextExtent);
  image = BlobToImage(info, data, size, exception);
  info = DestroyImageInfo(info);
  return image;
}

#endif
