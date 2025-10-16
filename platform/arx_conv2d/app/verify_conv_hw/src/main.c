#include "platform_info.h"
#include "ervp_printf.h"
#include "ervp_printf_section.h"
#include "ervp_variable_allocation.h"
#include "ervp_special_matrix_op.h"
#include "ervp_matrix.h"
#include "ervp_matrix_op.h"
#include "ervp_matrix_op_sw.h"
#include "ervp_core_id.h"
#include "ervp_assert.h"

#include "test_matrix.h"
#include "map_your_matrix_hw.h"

// this app is modified from "verify_conv_opt"

///////////////////////////////////////////////////////////////

#define NUN_MATRIX 1
#define INPUT_MATRIX_SIZE_H 22
#define INPUT_MATRIX_SIZE_W 22
#define KERNEL_MATRIX_SIZE_H 7
#define KERNEL_MATRIX_SIZE_W 7
#define RESULT_CHECK 1

#define IN_MATRIX_DATATYPE MATRIX_DATATYPE_SINT08
#define OUT_MATRIX_DATATYPE MATRIX_DATATYPE_SINT32
//#define MATRIX_DATATYPE MATRIX_DATATYPE_FLOAT32

ErvpMatrixInfo* input_info = NULL;
ErvpMatrixInfo* kernel_info = NULL;
ErvpMatrixInfo* output_info = NULL;
ErvpMatrixInfo* ref_info = NULL;

int main()
{
  if(EXCLUSIVE_ID==0)
  {
    ervp_mop_mapping_t* mop_mapping = matrix_op_mapping_alloc();
    map_your_matrix_function(mop_mapping);

    printf_section(1, "CONV");

    ervp_mconv_option_t conv_option;
    conv_option.value = 0;
    conv_option.br.rshift = 0;

    input_info = matrix_alloc(IN_MATRIX_DATATYPE, INPUT_MATRIX_SIZE_H, INPUT_MATRIX_SIZE_W, NULL);
    kernel_info = matrix_alloc(IN_MATRIX_DATATYPE, KERNEL_MATRIX_SIZE_H, KERNEL_MATRIX_SIZE_W, NULL);

    int o_num_row = matrix_conv_output_rows(input_info->num_row, kernel_info->num_row, conv_option.value);
    int o_num_col = matrix_conv_output_cols(input_info->num_col, kernel_info->num_col, conv_option.value);
    output_info = matrix_alloc(OUT_MATRIX_DATATYPE, o_num_row, o_num_col, NULL);
    ref_info = matrix_alloc(OUT_MATRIX_DATATYPE, o_num_row, o_num_col, NULL);

    for(int i=0; i<NUN_MATRIX; i=i+1)
    {
      // generate input
      generate_test_matrix(input_info, i);
      generate_test_matrix(kernel_info, i);
      matrix_conv_sw(input_info, kernel_info, ref_info, conv_option.value);
      mop_mapping->matrix_conv(mop_mapping, input_info, kernel_info, output_info, conv_option.value);
      
      if(RESULT_CHECK)
      {
        int all_are_equal = matrix_compare(output_info, ref_info, 1);
        if(!all_are_equal)
        {
          matrix_print(input_info);
          matrix_print(kernel_info);
          matrix_print(output_info);
          matrix_print(ref_info);
          assert(0);
          break;
        }
      }
    }
  }

  return 0;
}
