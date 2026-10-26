/* Decode with a coder chosen by the first byte, so formats without magic bytes (CUT, TGA, MAC, ...) are reachable. */
#include "harness_common.h"
#include "decode_formats.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  ExceptionInfo *exception;
  Image *image;
  int rc;

  if (size < 2)
    return -1;
  mayhem_init();
  exception = AcquireExceptionInfo();
  image = mayhem_read(data + 1, size - 1,
    mayhem_decode_formats[data[0] % (sizeof(mayhem_decode_formats) / sizeof(*mayhem_decode_formats))], exception);
  rc = image != NULL ? 0 : -1;
  if (image != NULL)
    image = DestroyImageList(image);
  exception = DestroyExceptionInfo(exception);
  return rc;
}
