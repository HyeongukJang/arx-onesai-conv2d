#ifndef __CONV_SHAREDOUTPUT_H__
#define __CONV_SHAREDOUTPUT_H__

#include "ervp_matrix.h"
#include "ervp_matrix_op.h"
#include "ervp_task.h"

ervp_task_wait_fx_t matrix_conv_sharedoutput_acc_by_add(ervp_mop_mapping_t *mop_mapping, int num_input, const ErvpMatrixInfo **input_info_list, const ErvpMatrixInfo **kernel_info_list, ErvpMatrixInfo *output_info, unsigned int conv_option_value, int init_ouptut);

#endif
