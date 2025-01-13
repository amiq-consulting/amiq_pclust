bit[4 - 1 : 0] flag_codes [4]= '{0, 0, 0, 0};

for (int i = 0 ; i < 4; i++) begin
	int j;
	$sscanf(flags[i], "val_%d", j);
	flag_codes[i][j] = 1'b1;
end

error2: assert((flag_codes[0] != 3'b010 || flag_codes[1] != 3'b010 || flag_codes[3] != 3'b010)) else 
 	$error("error2");

error1: assert((flag_codes[1] != 3'b100 || flag_codes[2] != 4'b0010 || flag_codes[3] != 3'b001) && (flag_codes[1] != 3'b100 || flag_codes[3] != 3'b001)) else 
 	$error("error1");
