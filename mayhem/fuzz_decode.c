/* Decode an arbitrary blob; ImageMagick picks the coder from the magic bytes. */
#include "harness_common.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  ExceptionInfo *exception;
  ImageInfo *info;
  Image *image;
  int rc;

  mayhem_init();
  exception = AcquireExceptionInfo();
  info = AcquireImageInfo();
  image = PingBlob(info, data, size, exception);
  if (image != NULL)
    image = DestroyImageList(image);
  info = DestroyImageInfo(info);
  image = mayhem_read(data, size, NULL, exception);
  rc = image != NULL ? 0 : -1;
  if (image != NULL)
    image = DestroyImageList(image);
  exception = DestroyExceptionInfo(exception);
  return rc;
}
