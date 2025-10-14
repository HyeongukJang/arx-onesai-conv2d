#include "platform_info.h"
#include "ervp_malloc.h"
#include "ervp_matrix_op_sw.h"
#include "ervp_printf.h"
#include "dca_matrix_info.h"

#include "dca_matrix_conv2d.h"

typedef struct
{
	dca_matrix_info_t mi;
	dca_matrix_info_t mk;
	dca_matrix_info_t mo;
	unsigned int stride_m1 : 16;
	unsigned int pad : 16;
} dca_matrix_conv2d_inst_t;

void dca_matrix_conv2d_hwinfo_elaborate(dca_matrix_conv2d_hwpara_t *hwpara, dca_matrix_conv2d_hwinfo_t *hwinfo)
{
	hwinfo->input_matrix_size = hwpara->input_matrix_size;
	hwinfo->kernel_matrix_size = hwpara->kernel_matrix_size;
	hwinfo->output_matrix_size = hwpara->output_matrix_size;
}

static void _dca_matrix_conv2d_request(const dca_matrix_conv2d_hwinfo_t *const hwinfo, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info)
{
	dca_matrix_conv2d_inst_t inst;
	inst.stride_m1 = 0;
	inst.pad = 0;

	dca_generate_matrix_info(mi_info, &(inst.mi));
	dca_generate_matrix_info(mk_info, &(inst.mk));
	dca_generate_matrix_info(mo_info, &(inst.mo));
	mmiox1_inst_push(hwinfo->mmiox_info, &inst, 1, 0);
}

ervp_task_wait_fx_t dca_matrix_conv2d_start(ervp_mop_mapping_t *mop_mapping, const dca_matrix_conv2d_hwinfo_t *const hwinfo, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info, unsigned int option_value)
{
	static ErvpMatrixInfo *temp = NULL;
	ervp_task_wait_fx_t task_wait_fx = NULL;
	if (mop_option_has_postprocess(option_value) || mop_option_is_acc(option_value))
	{
		ErvpMatrixInfo *previous = temp;
		temp = matrix_alloc(MATRIX_DATATYPE_SINT32, mo_info->num_row, mo_info->num_col, NULL);
		cache_flush_smart(3, mi_info->addr, mk_info->addr, mo_info->addr);
		_dca_matrix_conv2d_request(hwinfo, mi_info, mk_info, temp);
		dca_matrix_conv2d_wait(hwinfo);
		task_wait_fx = mop_mapping->matrix_perform_postprocess(mop_mapping, temp, mo_info, option_value);
		if (previous)
			matrix_free(previous);
	}
	else
	{
		cache_flush_smart(3, mi_info->addr, mk_info->addr, mo_info->addr);
		_dca_matrix_conv2d_request(hwinfo, mi_info, mk_info, mo_info);
		task_wait_fx = dca_matrix_conv2d_wait_fx(hwinfo);
	}
	return task_wait_fx;
}

ervp_task_wait_fx_t dca_matrix_conv2d_oneblock(ervp_mop_mapping_t *mop_mapping, const dca_matrix_conv2d_hwinfo_t *const hwinfo, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info, unsigned int conv_option_value)
{
  //printf("\ndca_matrix_conv2d_oneblock");
	assert(matrix_conv_check_size(mi_info, mk_info, mo_info, conv_option_value));

	ervp_mconv_option_t conv_option;
	conv_option.value = conv_option_value;
  //printf("\nacc: %d", conv_option.br.acc);
	ervp_task_wait_fx_t task_wait_fx = NULL;
	if ((conv_option.br.stride_m1 == 0) && (!matrix_conv_has_pad(conv_option_value)))
	{
		ervp_mop_option_t option;
		option.value = 0;
		option.br.acc = conv_option.br.acc;
		option.br.rshift = conv_option.br.rshift;
		option.br.performs_cliping = conv_option.br.performs_cliping;
		task_wait_fx = dca_matrix_conv2d_start(mop_mapping, hwinfo, mi_info, mk_info, mo_info, option.value);
	}
	else
	{
		matrix_conv_sw(mi_info, mk_info, mo_info, conv_option_value);
	}
	return task_wait_fx;
}
