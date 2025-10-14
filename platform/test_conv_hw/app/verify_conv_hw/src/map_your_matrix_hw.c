#include "platform_info.h"
#include "ip_instance_info.h"
#include "ervp_assert.h"
#include "ervp_printf.h"

#include "map_your_matrix_hw.h"
#include "dca_matrix_conv2d.h"

const char matrix_hw_name[] = "HW";

static void i_dca_matrix_conv00_conv(ervp_mop_mapping_t *mop_mapping, const ErvpMatrixInfo *input_info, const ErvpMatrixInfo *kernel_info, ErvpMatrixInfo *output_info, int options)
{
  dca_matrix_conv2d(mop_mapping, i_dca_matrix_conv00_info, input_info, kernel_info, output_info, options);
}

void map_your_matrix_function(ervp_mop_mapping_t* mop_mapping)
{
  /* map your own functions */
  mop_mapping->matrix_conv = i_dca_matrix_conv00_conv;
}
