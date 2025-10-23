#include "platform_info.h"
#include "ervp_malloc.h"
#include "ervp_matrix_op_sw.h"
#include "ervp_printf.h"
#include "ervp_caching.h"

#include "dca_matrix_info.h"
#include "dca_module_ext_memorymap_offset.h"
#include "dca_matrix_conv2d.h"

static const int OPCODE_CONV2D_COND = DCA_MATRIX_CONV2D_OPCODE_ACC_STORE;
static const int OPCODE_CONV2D = OPCODE_CONV2D_COND | DCA_MATRIX_CONV2D_OPCODE_ACC_CLEAR;

typedef struct
{
	dca_matrix_info_t mi;
	dca_matrix_info_t mk;
	dca_matrix_info_t mo;
	unsigned int stride_m1 : 4;
	unsigned int pad_amount : 4;
	unsigned int pad_has_rowu : 1;
	unsigned int pad_has_rowd : 1;
	unsigned int pad_has_colu : 1;
	unsigned int pad_has_cold : 1;
	unsigned int opcode : 2;
	unsigned int spare : 18;
} dca_matrix_conv2d_inst_t;

void dca_matrix_conv2d_hwinfo_elaborate(dca_matrix_conv2d_hwpara_t *hwpara, dca_matrix_conv2d_hwinfo_t *hwinfo)
{
	hwinfo->input_matrix_size = hwpara->input_matrix_size;
	hwinfo->kernel_matrix_size = hwpara->kernel_matrix_size;
	hwinfo->output_matrix_size = hwpara->output_matrix_size;
}

static void _dca_matrix_conv2d_request(const dca_matrix_conv2d_hwinfo_t *const hwinfo, int opcode, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info)
{
	dca_matrix_conv2d_inst_t inst;
	dca_inst_init_except_matrix_info(&inst, sizeof(dca_matrix_conv2d_inst_t), 3);
	inst.opcode = opcode;

	dca_matrix_info_generate(mi_info, &(inst.mi));
	dca_matrix_info_generate(mk_info, &(inst.mk));
	dca_matrix_info_generate(mo_info, &(inst.mo));

	// dca_matrix_conv2d_wait(hwinfo); // DO NOT remove even if not used
	mmiox1_inst_push(hwinfo->mmiox_info, &inst, 1, 0);
}

static ervp_task_wait_fx_t dca_matrix_conv2d_start(ervp_mop_mapping_t *mop_mapping, const dca_matrix_conv2d_hwinfo_t *const hwinfo, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info, unsigned int option_value)
{
	static ErvpMatrixInfo *temp = NULL;
	ervp_task_wait_fx_t task_wait_fx = NULL;
	if (mop_option_has_postprocess(option_value) || mop_option_is_acc(option_value))
	{
		ErvpMatrixInfo *previous = temp;
		temp = matrix_alloc(MATRIX_DATATYPE_SINT32, mo_info->num_row, mo_info->num_col, NULL);
		cache_flush_smart(3, mi_info->addr, mk_info->addr, mo_info->addr);
		_dca_matrix_conv2d_request(hwinfo, OPCODE_CONV2D, mi_info, mk_info, temp);
		dca_matrix_conv2d_wait(hwinfo);
		task_wait_fx = mop_mapping->matrix_perform_postprocess(mop_mapping, temp, mo_info, option_value);
		if (previous)
			matrix_free(previous);
	}
	else
	{
		cache_flush_smart(3, mi_info->addr, mk_info->addr, mo_info->addr);
		_dca_matrix_conv2d_request(hwinfo, OPCODE_CONV2D, mi_info, mk_info, mo_info);
		task_wait_fx = dca_matrix_conv2d_wait_fx(hwinfo);
	}
	return task_wait_fx;
}

ervp_task_wait_fx_t dca_matrix_conv2d_oneblock(ervp_mop_mapping_t *mop_mapping, const dca_matrix_conv2d_hwinfo_t *const hwinfo, const ErvpMatrixInfo *mi_info, const ErvpMatrixInfo *mk_info, ErvpMatrixInfo *mo_info, unsigned int conv_option_value)
{
	assert(matrix_conv_check_size(mi_info, mk_info, mo_info, conv_option_value));

	ervp_mconv_option_t conv_option;
	conv_option.value = conv_option_value;
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

ervp_task_wait_fx_t dca_matrix_conv2d_oneblock_sharedoutput(ervp_mop_mapping_t *mop_mapping, const dca_matrix_conv2d_hwinfo_t *const hwinfo, int num_input, const ErvpMatrixInfo **input_info_list, const ErvpMatrixInfo **kernel_info_list, ErvpMatrixInfo *output_info, unsigned int conv_option_value, int init_ouptut)
{
	assert(num_input);
	assert(matrix_conv_check_size(input_info_list[0], kernel_info_list[0], output_info, conv_option_value));

	ervp_task_wait_fx_t task_wait_fx = NULL;
	ervp_mconv_option_t conv_option;
	conv_option.value = conv_option_value;
	assert(conv_option.br.acc);

	if (num_input == 1)
	{
		if (init_ouptut)
			conv_option.br.acc = 0;
		task_wait_fx = dca_matrix_conv2d_oneblock(mop_mapping, hwinfo, input_info_list[0], kernel_info_list[0], output_info, conv_option.value);
	}
	else if (conv_option.br.rshift || conv_option.br.performs_cliping || (init_ouptut==0))
	{
		assert(0);
	}
	else
	{
		cache_flush_smart(-1);
		int opcode;
		opcode = DCA_MATRIX_CONV2D_OPCODE_ACC_CLEAR;
		_dca_matrix_conv2d_request(hwinfo, opcode, input_info_list[0], kernel_info_list[0], output_info);

		opcode = 0;
		for (int i = 1; i < (num_input - 1); i++)
		{
			_dca_matrix_conv2d_request(hwinfo, opcode, input_info_list[i], kernel_info_list[i], output_info);
		}
		opcode = DCA_MATRIX_CONV2D_OPCODE_ACC_STORE;
		_dca_matrix_conv2d_request(hwinfo, opcode, input_info_list[num_input - 1], kernel_info_list[num_input - 1], output_info);
		task_wait_fx = dca_matrix_conv2d_wait_fx(hwinfo);
	}
	return task_wait_fx;
}