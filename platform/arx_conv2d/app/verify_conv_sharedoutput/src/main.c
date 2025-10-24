#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_printf_section.h"
#include "ervp_variable_allocation.h"
#include "ervp_special_matrix_op.h"
#include "ervp_matrix.h"
#include "ervp_matrix_op_sw.h"
#include "ervp_core_id.h"
#include "ervp_assert.h"
#include "ervp_malloc.h"

#include "test_matrix.h"
#include "map_your_matrix_hw.h"

// this app is modified from "verify_conv_opt"

///////////////////////////////////////////////////////////////

#define INPUT_MATRIX_SIZE_C 8
#define INPUT_MATRIX_SIZE_H 32
#define INPUT_MATRIX_SIZE_W 32
#define KERNEL_MATRIX_SIZE_H 5
#define KERNEL_MATRIX_SIZE_W 5
#define RESULT_CHECK 1

#define IN_MATRIX_DATATYPE MATRIX_DATATYPE_SINT32
#define OUT_MATRIX_DATATYPE MATRIX_DATATYPE_SINT32

ErvpMatrixInfo** input_info_list = NULL;
ErvpMatrixInfo** kernel_info_list = NULL;
ErvpMatrixInfo* output_info = NULL;
ErvpMatrixInfo* ref_info = NULL;

int main()
{
  if(EXCLUSIVE_ID==0)
  {
    ervp_mop_mapping_t* mop_mapping = matrix_op_mapping_alloc();

    printf_section(1, "CONV");

    ervp_mconv_option_t conv_option;
    conv_option.value = 0;
    conv_option.br.rshift = 0;
    conv_option.br.acc = 1;

    input_info_list = calloc(sizeof(ErvpMatrixInfo *), INPUT_MATRIX_SIZE_C);
    kernel_info_list = calloc(sizeof(ErvpMatrixInfo *), INPUT_MATRIX_SIZE_C);
    for(unsigned char ch = 0; ch < INPUT_MATRIX_SIZE_C; ch++) {
      input_info_list[ch] = matrix_alloc(IN_MATRIX_DATATYPE, INPUT_MATRIX_SIZE_H, INPUT_MATRIX_SIZE_W, NULL);
      kernel_info_list[ch] = matrix_alloc(IN_MATRIX_DATATYPE, KERNEL_MATRIX_SIZE_H, KERNEL_MATRIX_SIZE_W, NULL);
      generate_test_matrix(input_info_list[ch], ch);
      generate_test_matrix(kernel_info_list[ch], ch);
    }

    int out_h = matrix_conv_output_rows(INPUT_MATRIX_SIZE_H, KERNEL_MATRIX_SIZE_H, conv_option.value);
    int out_w = matrix_conv_output_cols(INPUT_MATRIX_SIZE_W, KERNEL_MATRIX_SIZE_W, conv_option.value);
    output_info = matrix_alloc(OUT_MATRIX_DATATYPE, out_h, out_w, NULL);
    ref_info = matrix_alloc(OUT_MATRIX_DATATYPE, out_h, out_w, NULL);

    // SW
    mop_mapping->matrix_conv_sharedoutput(mop_mapping, INPUT_MATRIX_SIZE_C, input_info_list, kernel_info_list, ref_info, conv_option.value, 1);
    
    // HW
    map_your_matrix_function(mop_mapping);
    mop_mapping->matrix_conv_sharedoutput(mop_mapping, INPUT_MATRIX_SIZE_C, input_info_list, kernel_info_list, output_info, conv_option.value, 1);

    if(RESULT_CHECK)
    {
      int all_are_equal = matrix_compare(output_info, ref_info, 1);
      if(!all_are_equal)
      {
        printf("\n\nResult Output Matrix:"); matrix_print(output_info);
        printf("\n\nRef Output Matrix:"); matrix_print(ref_info);
        assert(0);
      }
    }
  }

  return 0;
}
