/* Decode a sniffed blob, then run one image operation chosen by the first two bytes. */
#include "harness_common.h"

static const MetricType metrics[] = {
  AbsoluteErrorMetric, MeanAbsoluteErrorMetric, MeanErrorPerPixelMetric, MeanSquaredErrorMetric,
  NormalizedCrossCorrelationErrorMetric, PeakAbsoluteErrorMetric, PeakSignalToNoiseRatioMetric,
  RootMeanSquaredErrorMetric, FuzzErrorMetric
};
static const MorphologyMethod morphs[] = {
  ConvolveMorphology, ErodeMorphology, DilateMorphology, OpenMorphology, CloseMorphology,
  EdgeMorphology, TopHatMorphology, DistanceMorphology, ThinningMorphology, ThickenMorphology
};
static const char *const kernels[] = { "Diamond:2", "Gaussian:0x1", "Sobel", "Disk:1.5", "Cross:1", "Octagon" };
static const ColorspaceType colorspaces[] = {
  GRAYColorspace, HSLColorspace, HSBColorspace, LabColorspace, CMYKColorspace, YCbCrColorspace,
  XYZColorspace, LogColorspace, Rec709YCbCrColorspace, HCLColorspace, LCHuvColorspace, sRGBColorspace
};
#define NELEM(a) (sizeof(a) / sizeof(*(a)))

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
  ExceptionInfo *exception;
  Image *image, *result = NULL, *other;
  unsigned op, arg;
  double distortion = 0.0;

  if (size < 3)
    return -1;
  mayhem_init();
  op = data[0] % 40;
  arg = data[1];
  exception = AcquireExceptionInfo();
  image = mayhem_read(data + 2, size - 2, NULL, exception);
  if (image == NULL)
    {
      exception = DestroyExceptionInfo(exception);
      return -1;
    }
  switch (op)
    {
    case 0: result = ResizeImage(image, image->columns / 2 + 1, image->rows / 2 + 1, (FilterTypes) (arg % SentinelFilter), 1.0, exception); break;
    case 1: result = RotateImage(image, arg * 1.41, exception); break;
    case 2: result = BlurImage(image, 0.0, 0.5 + arg % 6, exception); break;
    case 3: result = SharpenImage(image, 0.0, 0.5 + arg % 6, exception); break;
    case 4: result = AdaptiveThresholdImage(image, 1 + arg % 7, 1 + (arg >> 3) % 7, (ssize_t) arg - 128, exception); break;
    case 5: (void) BilevelImage(image, arg * 257.0); break;
    case 6: (void) PerceptibleImage(image, 1.0 + arg); break;
    case 7: (void) RandomThresholdImage(image, "20%x70%", exception); break;
    case 8:
      {
        ChannelFeatures *features = GetImageChannelFeatures(image, 1 + arg % 4, exception);
        if (features != NULL)
          features = (ChannelFeatures *) RelinquishMagickMemory(features);
        break;
      }
    case 9:
      other = BlurImage(image, 0.0, 1.0, exception);
      if (other != NULL)
        {
          result = CompareImages(image, other, metrics[arg % NELEM(metrics)], &distortion, exception);
          other = DestroyImage(other);
        }
      break;
    case 10:
      {
        QuantizeInfo *quantize = AcquireQuantizeInfo((const ImageInfo *) NULL);
        quantize->number_colors = 2 + arg;
        quantize->dither = (arg & 1) ? MagickTrue : MagickFalse;
        (void) QuantizeImage(quantize, image);
        quantize = DestroyQuantizeInfo(quantize);
        break;
      }
    case 11: result = EdgeImage(image, 0.5 + arg % 4, exception); break;
    case 12: result = CharcoalImage(image, 0.0, 0.5 + arg % 4, exception); break;
    case 13: (void) EqualizeImage(image); break;
    case 14: (void) NormalizeImage(image); break;
    case 15: (void) ContrastStretchImage(image, "2%x2%"); break;
    case 16:
      {
        KernelInfo *kernel = AcquireKernelInfo(kernels[(arg >> 4) % NELEM(kernels)]);
        if (kernel != NULL)
          {
            result = MorphologyImage(image, morphs[arg % NELEM(morphs)], 1 + (arg >> 6), kernel, exception);
            kernel = DestroyKernelInfo(kernel);
          }
        break;
      }
    case 17: result = SepiaToneImage(image, (arg / 255.0) * QuantumRange, exception); break;
    case 18: result = SwirlImage(image, arg - 128.0, exception); break;
    case 19: result = StatisticImage(image, (StatisticType) (arg % 8), 1 + arg % 5, 1 + (arg >> 3) % 5, exception); break;
    case 20: (void) TransformImageColorspace(image, colorspaces[arg % NELEM(colorspaces)]); break;
    case 21: result = UniqueImageColors(image, exception); break;
    case 22: result = EmbossImage(image, 0.0, 0.5 + arg % 4, exception); break;
    case 23: result = DespeckleImage(image, exception); break;
    case 24: result = ReduceNoiseImage(image, 0.5 + arg % 4, exception); break;
    case 25: result = EnhanceImage(image, exception); break;
    case 26: result = WaveImage(image, arg / 8.0, 4.0 + arg % 32, exception); break;
    case 27: result = ImplodeImage(image, (arg - 128) / 64.0, exception); break;
    case 28: (void) ModulateImage(image, "120,130,110"); break;
    case 29: result = ThumbnailImage(image, image->columns / 3 + 1, image->rows / 3 + 1, exception); break;
    case 30: result = SampleImage(image, 1 + arg % 40, 1 + (arg >> 2) % 40, exception); break;
    case 31: result = MagnifyImage(image, exception); break;
    case 32: result = ShearImage(image, arg / 4.0 - 16.0, (arg % 17) - 8.0, exception); break;
    case 33: result = MotionBlurImage(image, 0.0, 0.5 + arg % 6, arg * 1.4, exception); break;
    case 34: (void) AutoLevelImage(image); break;
    case 35: (void) LevelImage(image, "10%,90%"); break;
    case 36: (void) SigmoidalContrastImage(image, (arg & 1) ? MagickTrue : MagickFalse, "5x50%"); break;
    case 37: result = ShadeImage(image, (arg & 1) ? MagickTrue : MagickFalse, 30.0, 30.0 + arg, exception); break;
    case 38: (void) OrderedPosterizeImage(image, "o3x3", exception); break;
    default: result = UnsharpMaskImage(image, 0.0, 0.5 + arg % 4, 1.0, 0.05, exception); break;
    }
  if (result != NULL)
    result = DestroyImageList(result);
  image = DestroyImageList(image);
  exception = DestroyExceptionInfo(exception);
  return 0;
}
