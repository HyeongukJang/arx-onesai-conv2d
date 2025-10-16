#include "platform_info.h"
#include "ervp_assert.h"
#include "ervp_printf.h"
#include "conv_sharedoutput.h"

ervp_task_wait_fx_t matrix_conv_sharedoutput_acc_by_add(ervp_mop_mapping_t *mop_mapping, int num_input, const ErvpMatrixInfo **input_info_list, const ErvpMatrixInfo **kernel_info_list, ErvpMatrixInfo *output_info, unsigned int conv_option_value, int init_ouptut)
{
  static ErvpMatrixInfo *tmp_info = NULL;
  ervp_mconv_option_t conv_option;
  conv_option.value = conv_option_value;
  assert(conv_option.br.acc);
  conv_option.br.acc = 0;

  ervp_mop_option_t mop_option;
  mop_option.value = 0;
  mop_option.br.rshift = 0;
  mop_option.br.performs_cliping = 0;
  mop_option.br.acc = 0;

  ervp_task_wait_fx_t task_wait_fx = NULL;

  ErvpMatrixInfo *previous = tmp_info;
  tmp_info = matrix_alloc(output_info->datatype, output_info->num_row, output_info->num_col, NULL);

  if (init_ouptut)
    task_wait_fx = mop_mapping->matrix_zero(mop_mapping, output_info);
  for (int i = 0; i < num_input; i++)
  {
    task_wait_finish(task_wait_fx);
    task_wait_fx = mop_mapping->matrix_conv(mop_mapping, input_info_list[i], kernel_info_list[i], tmp_info, conv_option.value);

    task_wait_finish(task_wait_fx);
    task_wait_fx = mop_mapping->matrix_add(mop_mapping, tmp_info, output_info, output_info, mop_option.value);
  }
  if (previous)
    matrix_free(previous);

  return task_wait_fx;
}

