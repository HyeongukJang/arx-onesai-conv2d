#ifndef __DCA_MATRIX_CONV2D_H__
#define __DCA_MATRIX_CONV2D_H__

#include "ervp_matrix_op.h"
#include "ervp_mmiox1.h"

typedef struct
{
  unsigned int bw_addr;
  unsigned int ma_bw_data;
  unsigned int mb_bw_data;
  unsigned int mc_bw_data;
  unsigned int input_matrix_size;
  unsigned int kernel_matrix_size;
  unsigned int output_matrix_size;
  unsigned int tensor_para;
  unsigned int bw_config;
  unsigned int bw_status;
  unsigned int bw_log;
  unsigned int bw_inst;
  unsigned int bw_input;
  unsigned int bw_output;
  unsigned int config_default_value; // invalid due to the limit of data type, but not used
  unsigned int log_fifo_depth;
  unsigned int inst_fifo_depth;
  unsigned int input_fifo_depth;
  unsigned int output_fifo_depth;
} dca_matrix_conv2d_hwpara_t;

typedef struct
{
  const ervp_mmiox1_hwinfo_t* mmiox_info;
  unsigned int input_matrix_size : 16;
  unsigned int kernel_matrix_size : 16;
  unsigned int output_matrix_size : 16;
} dca_matrix_conv2d_hwinfo_t;

void dca_matrix_conv2d_hwinfo_elaborate(dca_matrix_conv2d_hwpara_t* hwpara, dca_matrix_conv2d_hwinfo_t* hwinfo);
void dca_matrix_conv2d(ervp_mop_mapping_t *mop_mapping, const dca_matrix_conv2d_hwinfo_t* const hwinfo, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info, int conv_options);

#endif
