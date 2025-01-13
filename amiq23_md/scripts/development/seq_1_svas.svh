bit[4 - 1 : 0] flag_codes [4]= '{0, 0, 0, 0};

for (int i = 0 ; i < 4; i++) begin
	int j;
	$sscanf(flags[i], "val_%d", j);
	flag_codes[i][j] = 1'b1;
end

error0: assert((flag_codes[0] != 3'b001 || flag_codes[2] != 4'b0100)) else 
 	$error("error0");
