#include "platform_info.h"
#include "ervp_assert.h"
#include "ervp_printf.h"
#include "ervp_matrix_op.h"
#include "ervp_blocked_matrix_op.h"

#include "ip_instance_info.h"
#include "dca_matrix_conv2d.h"
#include "conv_sharedoutput.h"

#include "map_your_matrix_hw.h"

const char matrix_hw_name[] = "DCA";

ervp_task_wait_fx_t i_dca_matrix_conv2d_oneblock(ervp_mop_mapping_t *mop_mapping, const ErvpMatrixInfo *ma_info, const ErvpMatrixInfo *mb_info, ErvpMatrixInfo *mc_info, int conv_options)
{
  return dca_matrix_conv2d_oneblock(mop_mapping, i_dca_matrix_conv00_info, ma_info, mb_info, mc_info, conv_options);
}

////////////////////////////////////////////////////////////////////////////

static ervp_blocked_matrix_info_t *blocked_info_conv;

ervp_task_wait_fx_t i_blocked_matrix_conv(ervp_mop_mapping_t *mop_mapping, const ErvpMatrixInfo *ma_info, const ErvpMatrixInfo *mb_info, ErvpMatrixInfo *mc_info, int conv_options)
{
  blocked_info_conv->block_size = i_dca_matrix_conv00_info->output_matrix_size + mb_info->num_row - 1;
  return blocked_matrix_conv(blocked_info_conv, ma_info, mb_info, mc_info, conv_options);
}

////////////////////////////////////////////////////////////////////////////

void map_your_matrix_function(ervp_mop_mapping_t *mop_mapping)
{
  /* map your own functions */
  blocked_info_conv = blocked_matrix_info_alloc();
  blocked_info_conv->subop_mapping = matrix_op_mapping_alloc();
  blocked_info_conv->subop_mapping->matrix_conv = i_dca_matrix_conv2d_oneblock;

  mop_mapping->matrix_conv = i_blocked_matrix_conv;

  mop_mapping->matrix_conv_sharedoutput = matrix_conv_sharedoutput_acc_by_add;
}
