//----------------------------------------------------------------------------
//                                                                          --
//     COPYRIGHT (C)                                AMIQ 2023               --
//     The document(s) may be used  and/or copied only with the written     --
//     permission from AMIQ or in accordance with the terms and             --
//     conditions  stipulated in the agreement/contract under which the     --
//     document(s) have been supplied.                                      --
//                                                                          --
//----------------------------------------------------------------------------
// Created by       : andbli
// Creation Date    : Jul 28, 2023
// Language version : SystemVerilog Standard IEEE 1800-2012
// Description      : Output coverage collector. Measures information
//                    related to the output items
//----------------------------------------------------------------------------

`ifndef AMIQ_DETERMINANT_COVERAGE_COLLECTOR
`define AMIQ_DETERMINANT_COVERAGE_COLLECTOR

// values of data_out bus
covergroup amiq_determinant_values_cg with function sample(bit signed [`DET_BUS_WIDTH - 1:0] bus);
	det_value_cp: coverpoint bus {
		bins max = {DET_OVERFLOW_VALUE};
		bins min = {DET_UNDERFLOW_VALUE};
		bins all_values [100] = {[DET_UNDERFLOW_VALUE + 1 :DET_OVERFLOW_VALUE - 1]};
		bins walking_one [] = generate_walking_one_bins();
	}
endgroup

// generate bins for walking one pattern
function amiq_det_queue_of_shortint_t generate_walking_one_bins(); /* @DVT_LINTER_WAIVER "Generated Code Waiver -this a systemverilog functionality" DISABLE SVTB.12.2.8 */
	automatic shortint generated_pattern = 0;
	for ( int i = 0 ; i < `DET_BUS_WIDTH ; i++) begin
		generated_pattern = `DET_BUS_WIDTH'b1 << i;
		generate_walking_one_bins.push_back(generated_pattern);
	end
endfunction

// Delay between signals
covergroup amiq_det_delay_cg with function sample(int unsigned delay);
	signal_delay_cp: coverpoint delay {
		bins mid [5] = {[`DET_MATRIX_SIZE ** 2:20]};
		bins big [30] = {[21:`DET_DELAY_MAX_VALUE - 1]};
		bins max [1] = {[`DET_DELAY_MAX_VALUE:$]};
	}
endgroup

class amiq_determinant_coverage_collector extends uvm_component;

	// register this component in the UVM Factory
	`uvm_component_utils(amiq_determinant_coverage_collector)

	// declares valid items analysis port
	`uvm_analysis_imp_decl(_valid_ap)
	// declares invalid items analysis port
	`uvm_analysis_imp_decl(_invalid_ap)

	// implements coverage collector valid items analysis port as implementation port (receiving end)
	uvm_analysis_imp_valid_ap #(amiq_determinant_item, amiq_determinant_coverage_collector) valid_ap;
	// implements coverage collector invalid items analysis port as implementation port (receiving end)
	uvm_analysis_imp_invalid_ap #(bit signed [`DET_BUS_WIDTH - 1:0], amiq_determinant_coverage_collector) invalid_ap;

	// output monitor virtual interface
	virtual amiq_determinant_if out_vif;

	// has the first item
	bit has_first_item = 0;

	// delay between overflows
	int ovf_del = 0;

	// had an overflow previously
	bit had_ovf = 0;

	// valid values on the determinant bus
	amiq_determinant_values_cg valid_output_values_cg;

	// invalid values on the determinant bus
	amiq_determinant_values_cg invalid_output_values_cg;

	// delay between output packets
	amiq_det_delay_cg det_valid_delay_cg;

	// delay between consecutive packets with overflow
	amiq_det_delay_cg overflow_delay_cg;

	// value of output bus at saturation
	covergroup det_overflow_value_cg with function sample(amiq_determinant_item out_item);
		det_overflow_value_cp: coverpoint out_item.determinant{
			bins positive_saturation = {DET_OVERFLOW_VALUE};
			bins negative_saturation = {DET_UNDERFLOW_VALUE};
		}
		overflow_cp : coverpoint out_item.overflow{
			bins active = {1};
			bins inactive = {0};
		}
		overflow_transitions_cp : coverpoint out_item.overflow{
			bins transitions = (0, 1 => 0, 1);
		}
		value_x_overflow: cross det_overflow_value_cp, overflow_cp;
	endgroup

	function new(string name = "amiq_determinant_coverage_collector", uvm_component parent);
		super.new(name, parent);

		// create the port for valid output items
		valid_ap = new("valid_ap", this);
		// create the port for invalid output values
		invalid_ap = new("invalid_ap", this);

		// create and set the names for the defined covergroups
		valid_output_values_cg = new();
		valid_output_values_cg.set_inst_name("valid_output_values_cg");

		invalid_output_values_cg = new();
		invalid_output_values_cg.set_inst_name("invalid_output_values_cg");

		det_valid_delay_cg = new();
		det_valid_delay_cg.set_inst_name("det_valid_delay_cg");

		overflow_delay_cg = new();
		overflow_delay_cg.set_inst_name("overflow_delay_cg");

		det_overflow_value_cg = new();
		det_overflow_value_cg.set_inst_name("det_overflow_value_cg");

	endfunction

	// build the coverage collector
	function void build_phase(uvm_phase phase);
		if (!uvm_config_db# (virtual amiq_determinant_if)::get (this, "*output_agent*", "output_if", out_vif))
			`uvm_fatal(get_name(), "Could not get the virtual interface handle.")
		super.build_phase(phase);
	endfunction

	virtual task run_phase(uvm_phase phase);
		forever begin
			reset_coverage_collector();
		end
	endtask

	// get valid item from monitor
	function void write_valid_ap(amiq_determinant_item received_item);

		// sample det value
		valid_output_values_cg.sample(received_item.determinant);
		det_overflow_value_cg.sample(received_item);

		if (has_first_item) begin

			// if this last item had overflow and this item has overflow
			// sample delay between consecutive overflows
			if (had_ovf && received_item.overflow) begin

				overflow_delay_cg.sample(received_item.pre_det_delay);

			end
			else if (received_item.overflow) begin
				had_ovf = 1;
			end

			// sample delay between consecutive det_valid assertions
			det_valid_delay_cg.sample(received_item.pre_det_delay);
		end
		else begin
			has_first_item = 1;
			if ( received_item.overflow)
				had_ovf = 1;
		end

	endfunction

	// get invalid bus value from monitor
	function void write_invalid_ap(shortint bus);
		// sample invalid det values
		invalid_output_values_cg.sample(bus);
	endfunction

	// bring all local variables to initial state
	function void reset_local_variables();
		has_first_item = 0;
		ovf_del = 0;
		had_ovf = 0;
	endfunction

	// reset coverage collector
	virtual task reset_coverage_collector();
		@(negedge out_vif.reset_n);
		reset_local_variables();
	endtask

endclass

`endif // AMIQ_DETERMINANT_COVERAGE_COLLECTOR
