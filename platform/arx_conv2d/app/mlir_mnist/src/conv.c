
// API.c
// Created by User on 2023-10-07.
// Written by Sangheon Lee from 2024-01-08.

#include "ervp_malloc.h"
#include "ervp_printf.h"
#include "ervp_assert.h"
#include "ervp_matrix_op.h"

#include "API.h"
#include "ONES_MATH.h"

// system setting
#define SYSTEM_32 1
#define SYSTEM_64 0

#if SYSTEM_32
#define INTEGER_TYPE int
#elif SYSTEM_64
#define INTEGER_TYPE long long int
#else
#error "Unknown Architecture"
#endif


int convolution_i8_shift(unsigned char* input, unsigned char* kernel,  int *bias, unsigned char* output,  unsigned char *outputOffset,
    unsigned char N, unsigned char C, unsigned char H, unsigned char W, unsigned char KN, unsigned char KH, unsigned char KW,
    unsigned char pad_size, unsigned char stride_size, bool doRelu, bool doBias, int* shift, unsigned char out_h, unsigned char out_w)


{
  printf("convolution_i8_shift\n");
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


  ervp_mconv_option_t conv_option;
  conv_option.value = 0;
  conv_option.br.rshift = 0;
  conv_option.br.performs_cliping = 0;
  conv_option.br.acc = 0;


  // convolution operation
  ptr_output = output;


  // singed_kernel
  signed char *signed_kernel = malloc(KN*C*KH*KW);
  for(unsigned char kn = 0; kn < KN; kn++) {                                      // for each kernel tensor
    for(unsigned char c_ = 0; c_ < C; c_++) {
      for(unsigned char r_ind = 0; r_ind < KH; r_ind++) {
        for(unsigned char c_ind = 0; c_ind < KW; c_ind++) {
          int idx = (kn * C * KH * KW) + (c_ * KH * KW) + (r_ind * KW) + c_ind;
          *(signed_kernel + idx) = (signed char)(((INTEGER_TYPE)*(kernel + idx)) - 127);
        }
      }
    }
  }
  // int kernel
  INTEGER_TYPE *conv_output = malloc(out_h*out_w);

  //ErvpMatrixInfo **input_info_list = calloc(sizeof(ErvpMatrixInfo *), C);
  //for(unsigned char c_ = 0; c_ < C; c_++) {
  //  
  //}

  //ErvpMatrixInfo **output_info_list = calloc(sizeof(ErvpMatrixInfo *), KN);
  //for(unsigned char kn = 0; kn < KN; kn++) {
  //}

  for(unsigned char n = 0; n < N; n++) {                                                      // for each input tensor
    for(unsigned char kn = 0; kn < KN; kn++) {                                      // for each kernel tensor

      // dododo mapping->matrix_conv_sharedoutput
      for(unsigned char r_offset = 0; r_offset <= H - KH; r_offset += stride_size) {          // local area offset to compute
        for(unsigned char c_offset = 0; c_offset <= W - KW; c_offset += stride_size) {      // local area offset to compute
          // for 32-bit architecture, the operation proceeds in 32 bits, 
          INTEGER_TYPE temp = 0;

          // compute sum of multiplication
          for(unsigned char r_ind = 0; r_ind < KH; r_ind++) {
            for(unsigned char c_ind = 0; c_ind < KW; c_ind++) {
              for(unsigned char c_ = 0; c_ < C; c_++) {
                // 입력 값 (unsigned char → int)
                INTEGER_TYPE input_val = *(padded + (n * C * H * W) + (c_ * H * W) + ((r_offset + r_ind) * W) + (c_offset + c_ind));
                // 커널 값: 원래 uint8 값에서 zero_point 127을 뺀 후, int 형으로 사용
                //INTEGER_TYPE kernel_val = ((INTEGER_TYPE)*(kernel + (kn * C * KH * KW) + (c_ * KH * KW) + (r_ind * KW) + c_ind)) - 127;
                INTEGER_TYPE kernel_val = (INTEGER_TYPE)*(signed_kernel + (kn * C * KH * KW) + (c_ * KH * KW) + (r_ind * KW) + c_ind);
                temp += input_val * kernel_val;
                //temp += *(padded + (n * H * W * C) + ((r_offset + r_ind) * W * C) + ((c_offset + c_ind) * C) + c) * *(kernel + (kn * KH * KW * C) + (r_ind * KW * C) + (c_ind * C) + c);
              }
            }
          }

          *(conv_output + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = temp;
        }
      }

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

      // dododo mapping->matrix_perform_postprocess
      // rounding
      // shift
      // detect underflow/overflow (cliping)
      for(unsigned char r_offset = 0; r_offset <= H - KH; r_offset += stride_size) {          // local area offset to compute
        for(unsigned char c_offset = 0; c_offset <= W - KW; c_offset += stride_size) {      // local area offset to compute
          INTEGER_TYPE temp = *(conv_output + ((r_offset / stride_size) * out_w) + (c_offset / stride_size));
          INTEGER_TYPE rounding = 1 << (shift[kn]-1);
          temp = (temp+rounding) >> shift[kn];
          temp = temp + (int)outputOffset[0];
          // detect underflow/overflow
          if(temp > 255)       *(ptr_output + (n * KN * out_h * out_w) + (kn * out_h * out_w) + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = 255;
          else if(temp < 0)    *(ptr_output + (n * KN * out_h * out_w) + (kn * out_h * out_w) + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = 0;
          else                *(ptr_output + (n * KN * out_h * out_w) + (kn * out_h * out_w) + ((r_offset / stride_size) * out_w) + (c_offset / stride_size)) = temp;
        }
      }
    }
  }

  free(padded);
  return 0;
}

