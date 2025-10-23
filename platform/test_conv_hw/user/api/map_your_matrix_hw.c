#include "platform_info.h"
#include "ervp_assert.h"
#include "ervp_printf.h"
#include "ervp_matrix_op_transform.h"
#include "ervp_blocked_matrix_op.h"
#include "ervp_caching.h"

#include "ip_instance_info.h"
#include "dca_matrix_conv2d.h"

#include "map_your_matrix_hw.h"

const char matrix_hw_name[] = "DCA";

////////////////////////////////////////////////////////////////////////////

static int CHECK_FUNCTION = 0;

////////////////////////////////////////////////////////////////////////////

ervp_task_wait_fx_t i_dca_matrix_conv2d_oneblock(ervp_mop_mapping_t *mop_mapping, const ErvpMatrixInfo *ma_info, const ErvpMatrixInfo *mb_info, ErvpMatrixInfo *mc_info, int conv_options)
{
  if (CHECK_FUNCTION)
    printf_function();
  return dca_matrix_conv2d_oneblock(mop_mapping, i_dca_matrix_conv00_info, ma_info, mb_info, mc_info, conv_options);
}

ervp_task_wait_fx_t i_dca_matrix_conv2d_oneblock_sharedoutput(ervp_mop_mapping_t *mop_mapping, int num_input, const ErvpMatrixInfo **input_info_list, const ErvpMatrixInfo **kernel_info_list, ErvpMatrixInfo *output_info, int conv_options, int init_ouptut)
{
  if (CHECK_FUNCTION)
    printf_function();
  return dca_matrix_conv2d_oneblock_sharedoutput(mop_mapping, i_dca_matrix_conv00_info, num_input, input_info_list, kernel_info_list, output_info, conv_options, init_ouptut);
}

////////////////////////////////////////////////////////////////////////////

static ervp_blocked_matrix_info_t *blocked_info_conv;

ervp_task_wait_fx_t i_blocked_matrix_conv(ervp_mop_mapping_t *mop_mapping, const ErvpMatrixInfo *ma_info, const ErvpMatrixInfo *mb_info, ErvpMatrixInfo *mc_info, int conv_options)
{
  if (CHECK_FUNCTION)
    printf_function();
  blocked_info_conv->block_size = i_dca_matrix_conv00_info->output_matrix_size + mb_info->num_row - 1;
  return blocked_matrix_conv(blocked_info_conv, ma_info, mb_info, mc_info, conv_options);
}

ervp_task_wait_fx_t i_blocked_matrix_conv_sharedinput(ervp_mop_mapping_t *mop_mapping, int num_output, const ErvpMatrixInfo *input_info, const ErvpMatrixInfo **kernel_info_list, ErvpMatrixInfo **output_info_list, int conv_options)
{
  if (CHECK_FUNCTION)
    printf_function();
  blocked_info_conv->block_size = i_dca_matrix_conv00_info->output_matrix_size + kernel_info_list[0]->num_row - 1;
  return blocked_matrix_conv_sharedinput(blocked_info_conv, num_output, input_info, kernel_info_list, output_info_list, conv_options);
}

ervp_task_wait_fx_t i_blocked_matrix_conv_sharedoutput(ervp_mop_mapping_t *mop_mapping, int num_input, const ErvpMatrixInfo **input_info_list, const ErvpMatrixInfo **kernel_info_list, ErvpMatrixInfo *output_info, int conv_options, int init_ouptut)
{
  if (CHECK_FUNCTION)
    printf_function();
  blocked_info_conv->block_size = i_dca_matrix_conv00_info->output_matrix_size + kernel_info_list[0]->num_row - 1;
  return blocked_matrix_conv_sharedoutput(blocked_info_conv, num_input, input_info_list, kernel_info_list, output_info, conv_options, init_ouptut);
}

////////////////////////////////////////////////////////////////////////////

void map_your_matrix_function(ervp_mop_mapping_t *mop_mapping)
{
  /* map your own functions */
  blocked_info_conv = blocked_matrix_info_alloc();
  blocked_info_conv->subop_mapping = matrix_op_mapping_alloc();
  blocked_info_conv->subop_mapping->matrix_conv = i_dca_matrix_conv2d_oneblock;
  blocked_info_conv->subop_mapping->matrix_conv_sharedoutput = i_dca_matrix_conv2d_oneblock_sharedoutput;

  mop_mapping->matrix_conv = i_blocked_matrix_conv;
  mop_mapping->matrix_conv_sharedinput = i_blocked_matrix_conv_sharedinput;
  mop_mapping->matrix_conv_sharedoutput = i_blocked_matrix_conv_sharedoutput;
}
