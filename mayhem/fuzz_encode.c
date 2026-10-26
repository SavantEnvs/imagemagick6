/* Decode a sniffed blob, then re-encode it with the writer chosen by the first byte. */
#include "harness_common.h"
#include "encode_formats.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  ExceptionInfo *exception;
  ImageInfo *info;
  Image *image;
  const char *format;
  void *blob;
  size_t length = 0;

  if (size < 2)
    return -1;
  mayhem_init();
  format = mayhem_encode_formats[data[0] % (sizeof(mayhem_encode_formats) / sizeof(*mayhem_encode_formats))];
  exception = AcquireExceptionInfo();
  image = mayhem_read(data + 1, size - 1, NULL, exception);
  if (image == NULL)
    {
      exception = DestroyExceptionInfo(exception);
      return -1;
    }
  info = AcquireImageInfo();
  (void) CopyMagickString(info->magick, format, MaxTextExtent);
  blob = ImageToBlob(info, image, &length, exception);
  if (blob != NULL)
    blob = RelinquishMagickMemory(blob);
  info = DestroyImageInfo(info);
  image = DestroyImageList(image);
  exception = DestroyExceptionInfo(exception);
  return 0;
}
