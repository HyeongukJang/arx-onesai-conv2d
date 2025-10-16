#include "ervp_malloc.h"
#include "ervp_printf.h"
#include "ervp_assert.h"
#include "ervp_matrix.h"
#include "ervp_matrix_op.h"
#include "ervp_matrix_op_sw.h"
#include "ervp_matrix_op_transform.h"

#include "map_your_matrix_hw.h"

#include "API.h"
#include "ONES_MATH.h"

#define INTEGER_TYPE int

int convolution_i8_shift(unsigned char* input, unsigned char* kernel,  int *bias, unsigned char* output,  unsigned char *outputOffset,
    unsigned char N, unsigned char C, unsigned char H, unsigned char W, unsigned char KN, unsigned char KH, unsigned char KW,
    unsigned char pad_size, unsigned char stride_size, bool doRelu, bool doBias, int* shift, unsigned char out_h, unsigned char out_w)
{
  // exception handling
  if(N == 0 || C == 0 || H == 0 || W == 0 || KN == 0 || KH == 0 || KW == 0)    return -1;
  else if(H < KH || W < KW)    return -1;

  assert(N == 1);

  // padding
  unsigned char P = pad_size;
  unsigned char* padded = (unsigned char*) malloc(N * C * (H + 2 * P) * (W + 2 * P) * sizeof(unsigned char));

  unsigned char* ptr_input;
  unsigned char* ptr_output = padded;

  for(int n = 0; n < N; n++) {
    for(int c = 0; c < C; c++) {
      for(int p = 0; p < P; p++) {
        for(int x = 0; x < (W + 2 * P); x++) {
          *ptr_output++ = 0;                        // set upper row to zero
        }
      }
      for(int y = 0; y < H; y++) {
        for(int p = 0; p < P; p++) {
          *ptr_output++ = 0;                        // set left column to zero
        }
        ptr_input = input + n * C * H * W + c * H * W + y * W;
        for(int x = 0; x < W; x++) {
          *ptr_output++ = *ptr_input++;             // copy values
        }
        for(int p = 0; p < P; p++) {
          *ptr_output++ = 0;                        // set right column to zero
        }
      }
      for(int p = 0; p < P; p++) {
        for(int x = 0; x < (W + 2 * P); x++) {
          *ptr_output++ = 0;                        // set lower row to zero
        }
      }
    }
  }
  H = H + 2 * P;
  W = W + 2 * P;

  // convolution operation
  ptr_output = output;

  // singed_kernel
  signed char *signed_kernel = malloc(sizeof(signed char)*KN*C*KH*KW);
  for(unsigned char kn = 0; kn < KN; kn++) {                                      // for each kernel tensor
    for(unsigned char ch = 0; ch < C; ch++) {
      for(unsigned char r_ind = 0; r_ind < KH; r_ind++) {
        for(unsigned char c_ind = 0; c_ind < KW; c_ind++) {
          int idx = (kn * C * KH * KW) + (ch * KH * KW) + (r_ind * KW) + c_ind;
          *(signed_kernel + idx) = (signed char)(((INTEGER_TYPE)*(kernel + idx)) - 127);
        }
      }
    }
  }
  ervp_mconv_option_t conv_option;
  conv_option.value = 0;
  conv_option.br.rshift = 0;
  conv_option.br.performs_cliping = 0;
  conv_option.br.acc = 1;

  static ervp_mop_mapping_t *mop_mapping = NULL;
  if(mop_mapping == NULL)
  {
    mop_mapping = matrix_op_mapping_alloc();
    map_your_matrix_function(mop_mapping);
  }

  ErvpMatrixInfo **input_info_list = calloc(sizeof(ErvpMatrixInfo *), C);
  ErvpMatrixInfo **kernel_info_list = calloc(sizeof(ErvpMatrixInfo *), C);
  for(unsigned char ch = 0; ch < C; ch++) {
    input_info_list[ch] = matrix_generate_info(MATRIX_DATATYPE_SINT08, H, W, (padded + (ch * H * W)), NULL);
    kernel_info_list[ch] = matrix_generate_info(MATRIX_DATATYPE_SINT08, KH, KW, NULL, NULL);
  }

  ErvpMatrixInfo *output_info = matrix_alloc(MATRIX_DATATYPE_SINT32, out_h, out_w, NULL);
  INTEGER_TYPE *conv_output = output_info->addr;

  //ervp_task_wait_fx_t task_wait_fx = NULL;
  for(unsigned char n = 0; n < N; n++) {                                                      // for each input tensor
    for(unsigned char kn = 0; kn < KN; kn++) {                                      // for each kernel tensor

      for(unsigned char ch = 0; ch < C; ch++) {
        kernel_info_list[ch]->addr = (void *)(signed_kernel + (kn * C * KH * KW) + (ch * KH * KW));
      }
      // conv hw
      mop_mapping->matrix_conv_sharedoutput(mop_mapping, C, input_info_list, kernel_info_list, output_info, conv_option.value, 1);

      // doBias
      if(doBias) {
        for(unsigned char r_offset = 0; r_offset <= H - KH; r_offset += stride_size) {          // local area offset to compute
          for(unsigned char c_offset = 0; c_offset <= W - KW; c_offset += stride_size) {      // local area offset to compute
            *(conv_output + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) += *(bias + kn);
          }
        }
      }

      if(doRelu) {
        for(unsigned char r_offset = 0; r_offset <= H - KH; r_offset += stride_size) {          // local area offset to compute
          for(unsigned char c_offset = 0; c_offset <= W - KW; c_offset += stride_size) {      // local area offset to compute
            INTEGER_TYPE *ptemp = (conv_output + ((r_offset / stride_size) * out_w) + (c_offset / stride_size));
            // doRelu
            if(*ptemp < 0) {
              *ptemp = 0;
            }
          }
        }
      }

      // mop_mapping->matrix_perform_postprocess
      // rounding
      // shift
      // detect underflow/overflow (cliping)
      for(unsigned char r_offset = 0; r_offset <= H - KH; r_offset += stride_size) {          // local area offset to compute
        for(unsigned char c_offset = 0; c_offset <= W - KW; c_offset += stride_size) {      // local area offset to compute
          INTEGER_TYPE temp = *(conv_output + ((r_offset / stride_size) * out_w) + (c_offset / stride_size));
          INTEGER_TYPE rounding = 1 << (shift[kn]-1);
          temp = (temp+rounding) >> shift[kn];
          temp = temp + (int)outputOffset[0];
          if(temp > 255)       *(ptr_output + (n * KN * out_h * out_w) + (kn * out_h * out_w) + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = 255;
          else if(temp < 0)    *(ptr_output + (n * KN * out_h * out_w) + (kn * out_h * out_w) + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = 0;
          else                *(ptr_output + (n * KN * out_h * out_w) + (kn * out_h * out_w) + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = temp;
        }
      }
    }
  }

  free(signed_kernel);
  free(padded);

  free(input_info_list);
  free(kernel_info_list);

  matrix_free(output_info);

  return 0;
}

