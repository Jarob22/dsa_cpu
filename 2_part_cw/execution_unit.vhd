library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.util.all;

entity execution_unit is

    generic
    (
        gate_delay: time;     -- delay per gate for simulation only
        word_size:  positive; -- width of data bus in bits
        rom_size:   positive; -- size of ROM in words
        ram_size:   positive; -- size of RAM in words
        intr_size:  positive; -- number of interrupt lines
        ports_in:   positive; -- number of 8 bit wide input ports
        ports_out:  positive  -- number of 8 bit wide output ports
    );

    port
    (
        clk:           in  std_logic                                             :=            'X';  -- clock
        rst:           in  std_logic                                             :=            'X';  -- rst
        en:            in  std_logic                                             :=            'X';  -- enable

--synopsys synthesis_off
        test_pc:       out unsigned((n_bits(rom_size) - 1) downto 0)             := (others => 'X'); -- program counter
        test_opcode:   out std_logic_vector(7 downto 0)                          := (others => 'X'); -- instruction opcode
        test_ins_data: out std_logic_vector(word_size - 9 downto 0)              := (others => 'X'); -- instruction data
        
        test_sp:       out unsigned(        (n_bits(ram_size) - 1) downto 0) := (others => '0');          -- stack pointer
        test_sr:       out std_logic_vector((       word_size - 1) downto 0) := (others => '0');          -- status register
--synopsys synthesis_on

        rom_en:        out std_logic                                             	:=            'X';  -- ROM enable (set high when wanting to read)
        rom_addr:      out std_logic_vector((n_bits(rom_size - 1) - 1) downto 0) := (others => 'X'); -- ROM address to read
        rom_data:      in  std_logic_vector((word_size - 1) downto 0)            := (others => 'Z'); -- ROM data (the 8 digit hex word)
        
        ram_wr:        out std_logic                                         :=            '0';           -- RAM write
        ram_waddr:     out std_logic_vector((n_bits(ram_size) - 1) downto 0) := (others => '0');          -- RAM address to write
        ram_wdata:     out std_logic_vector((       word_size - 1) downto 0) := (others => '0');          -- RAM data to write
        ram_rd:        out std_logic                                         :=            '0';           -- RAM read
        ram_raddr:     out std_logic_vector((n_bits(ram_size) - 1) downto 0) := (others => '0');          -- RAM address to read
        ram_rdata:     in  std_logic_vector((       word_size - 1) downto 0) := (others => 'X');          -- RAM data to read

        intr:          in  std_logic_vector((       intr_size - 1) downto 0) := (others => 'X');          -- Interrupt lines


        io_in:         in  byte_vector((ports_in - 1) downto 0)                  := (others => byte_unknown); -- 8 bit wide input ports (buttons/switches/dcf/msf/rx)
        io_out:        out byte_vector((ports_out - 1) downto 0)                 := (others => byte_null)     -- 8 bit wide output ports

    );

end execution_unit;

architecture syn of execution_unit is

  signal curr_rom_en: std_logic	:= 'X';
  signal next_rom_en: std_logic := 'X';
  
  signal curr_sample_io_out: byte_vector((ports_out - 1) downto 0)  := (others => byte_null);
  signal next_sample_io_out: byte_vector((ports_out - 1) downto 0)  := (others => byte_null);
  signal internal_io_out : byte_vector((ports_out - 1) downto 0) := (others => byte_null);
  
  signal internal_opcode: std_logic_vector(7 downto 0) := (others => 'X');
  signal next_test_opcode: std_logic_vector(7 downto 0) := (others => 'X');
  signal curr_test_opcode: std_logic_vector(7 downto 0) := (others => 'X');
  
  signal start_of_rom: std_logic_vector((n_bits(rom_size) - 1) downto 0) := "001000";
  
  
  signal io_out_port: std_logic_vector(7 downto 0) := (others => 'X');
  signal and_argument: std_logic_vector(7 downto 0) := (others => 'X');
  signal xor_argument: std_logic_vector(7 downto 0) := (others => 'X');
  
  signal curr_test_pc: std_logic_vector((n_bits(rom_size) - 1) downto 0) := start_of_rom;
  signal next_test_pc: std_logic_vector((n_bits(rom_size) - 1) downto 0) := start_of_rom;
  
  signal internal_test_ins_data: std_logic_vector(word_size - 9 downto 0) := (others => 'X');
  
  signal test_flag: std_logic := 'X';
  signal next_test_flag: std_logic := 'X';
  
  signal curr_test_sp: unsigned((n_bits(ram_size) - 1) downto 0) := (others => '1');
  signal next_test_sp: unsigned((n_bits(ram_size) - 1) downto 0) := (others => '1');
  
  signal curr_test_sr: std_logic_vector((word_size - 1) downto 0) := (others => '0');
  signal next_test_sr: std_logic_vector((word_size - 1) downto 0) := (others => '0');
  
  signal curr_interrupt_register: std_logic_vector(7 downto 0) := (others => '0');
  signal next_interrupt_register: std_logic_vector(7 downto 0) := (others => '0');

begin

rom_en <= '1' after gate_delay;
io_out <= internal_io_out;	
rom_addr <= std_logic_vector(next_test_pc);
--synopsys synthesis_off
test_pc <= (unsigned(curr_test_pc)	);
test_opcode <= internal_opcode;
test_ins_data <= internal_test_ins_data;
test_sp <= curr_test_sp;
test_sr <= curr_test_sr;
--synopsys synthesis_on
internal_opcode <= rom_data(31 downto 24);
io_out_port <= rom_data(23 downto 16);
and_argument <= rom_data(15 downto 8);
xor_argument <= rom_data(7 downto 0);
internal_test_ins_data <= rom_data(23 downto 0);

ram_rd <= '1';
ram_raddr <=  std_logic_vector(curr_test_sp + 1);


  
  
  process(clk, rst)
  begin
  
  	if (rst = '1') then -- If reset
  	
  		curr_sample_io_out <= (others => byte_null);
  		curr_test_pc <= "001000";
  		test_flag <= 'X';
  		curr_test_sp <= (others => '1');
  		curr_test_sr <= (others => '0');
  		curr_interrupt_register <= (others => '0');
  	
		elsif clk'event and (clk = '1') then	--On clock ri
		
			curr_sample_io_out <= next_sample_io_out;
			curr_test_pc <= next_test_pc;
			test_flag <= next_test_flag;
			curr_test_sp <= next_test_sp;
			curr_test_sr <= next_test_sr;
			curr_interrupt_register <= next_interrupt_register;
			
		end if;
  
  end process;
  
  process(internal_io_out,  curr_sample_io_out) --Sampling process for io_out with an inhibitor for when we want to change the value
  begin
  	
  		next_sample_io_out <= internal_io_out;
  	
  end process;
  
  process(intr, curr_interrupt_register, ram_rdata, curr_test_sp, io_in, rst, test_flag, internal_test_ins_data, curr_sample_io_out, io_out_port, and_argument, xor_argument, curr_test_pc, internal_opcode, curr_test_sp, curr_test_sr)
  begin
  
			next_test_pc <= curr_test_pc;
			next_test_sp <= curr_test_sp;
			next_test_sr <= curr_test_sr;
			next_test_flag <= test_flag;
			ram_wr <= '0';
			ram_waddr <= (others => '0');
			ram_wdata <= (others => '0');
			internal_io_out <= curr_sample_io_out;
			next_interrupt_register <= curr_interrupt_register;
			
			if (intr /= "00000000") then
				if (intr(7) = '1') then
					next_interrupt_register(7) <= '1';
				end if;
				
				if (intr(6) = '1') then
					next_interrupt_register(6) <= '1';
				end if;
				
				if (intr(5) = '1') then
					next_interrupt_register(5) <= '1';
				end if;
				
				if (intr(4) = '1') then
					next_interrupt_register(4) <= '1';
				end if;
				
				if (intr(3) = '1') then
					next_interrupt_register(3) <= '1';
				end if;
				
				if (intr(2) = '1') then
					next_interrupt_register(2) <= '1';
				end if;
				
				if (intr(1) = '1') then
					next_interrupt_register(1) <= '1';
				end if;
				
				if (intr(0) = '1') then
					next_interrupt_register(0) <= '1';
				end if;
			end if;
					
			if (curr_interrupt_register /= "00000000") and (curr_test_sr(0) = '1') then
				next_test_sr(0) <= '0';
			
				ram_wr <= '1'; --enable RAM writing
				ram_waddr <= std_logic_vector(curr_test_sp);
				ram_wdata((n_bits(rom_size) - 1) downto 0) <= std_logic_vector(unsigned(curr_test_pc)); 
				ram_wdata((word_size - 1) downto (word_size/2)) <= curr_test_sr(15 downto 0);
				next_test_sp <= (curr_test_sp - 1); 
			
				if (curr_interrupt_register(7) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(7, n_bits(rom_size-1)));
					next_interrupt_register(7) <= '0';
				end if;
				
				if (curr_interrupt_register(6) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(6, n_bits(rom_size-1)));
					next_interrupt_register(6) <= '0';
				end if;
				
				if (curr_interrupt_register(5) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(5, n_bits(rom_size-1)));
					next_interrupt_register(5) <= '0';
				end if;
				
				if (curr_interrupt_register(4) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(4, n_bits(rom_size-1)));
					next_interrupt_register(4) <= '0';
				end if;
				
				if (curr_interrupt_register(3) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(3, n_bits(rom_size-1)));
					next_interrupt_register(3) <= '0';
				end if;
				
				if (curr_interrupt_register(2) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(2, n_bits(rom_size-1)));
					next_interrupt_register(2) <= '0';
				end if;
				
				if (curr_interrupt_register(1) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(1, n_bits(rom_size-1)));
					next_interrupt_register(1) <= '0';
				end if;
				
				if (curr_interrupt_register(0) = '1') then
					next_test_pc <= std_logic_vector(to_unsigned(0, n_bits(rom_size-1)));
					next_interrupt_register(0) <= '0';
				end if;
				
			else
		
				if (internal_opcode = "00000000") then --IUC
					next_test_pc <= std_logic_vector(unsigned(curr_test_pc) + 1);
			
				elsif (internal_opcode = "00000001") then --HUC
					--stuff
			
				elsif (internal_opcode = "00000010") then --BUC
					next_test_pc <= std_logic_vector(internal_test_ins_data((n_bits(rom_size) - 1) downto 0));
			
				elsif (internal_opcode = "00000011") then --BIC
		
					if(test_flag = '1') then
																							
						next_test_pc <= std_logic_vector(internal_test_ins_data((n_bits(rom_size) - 1) downto 0));
			
					elsif(test_flag = '0') then

						next_test_pc <= std_logic_vector(unsigned(curr_test_pc) + 1);
			
					end if;
			
				elsif (internal_opcode = "00000100") then --SETO
					internal_io_out(to_integer(unsigned(io_out_port))) <= std_logic_vector((curr_sample_io_out(to_integer(unsigned(io_out_port)))) and and_argument) xor xor_argument;
					next_test_pc <= std_logic_vector(unsigned(curr_test_pc) + 1);
				

			
				elsif (internal_opcode = "00000101") then --TSTI
		
					next_test_pc <= std_logic_vector(unsigned(curr_test_pc) + 1);

					if ((std_logic_vector((io_in(to_integer(unsigned(io_out_port))) and and_argument) xor xor_argument)) = "00000000") then --It is zero, branch
		
						next_test_flag <= '1';
						next_test_sr(1) <= '1';
			
					else --Don't branch
			
						next_test_flag <= '0';
						next_test_sr(1) <= '0';
		
					end if;
			
				elsif (internal_opcode = "00000110") then --BSR
			
					ram_wr <= '1'; --enable RAM writing
					ram_waddr <= std_logic_vector(curr_test_sp); --set the first RAM address to be written to, to be the current stack pointer (initialised to "1111111")
					ram_wdata((n_bits(rom_size) - 1) downto 0) <= std_logic_vector(unsigned(curr_test_pc) + 1); --set the data to be written to the current program counter + 1
					next_test_sp <= (curr_test_sp - 1); --decrement the stack pointer
					next_test_pc <= std_logic_vector(internal_test_ins_data((n_bits(rom_size) - 1) downto 0)); --set the program counter to the address of the BSR command
			
				elsif (internal_opcode = "00000111") then --RSR
					 --set the ram address to be written to, to be the current stack pointer - 1 (curr stack pointer points to the next empty address in RAM)
			    
			    next_test_pc <= ram_rdata((n_bits(rom_size) - 1) downto 0); --set program counter to the data stored in ram 
			    next_test_sp <= (curr_test_sp + 1); --increment the stack pointer
				
		
				elsif (internal_opcode = "00001000") then --RIR
		
					next_test_pc <= ram_rdata((n_bits(rom_size) - 1) downto 0); --set program counter to the data stored in ram 
			    next_test_sp <= (curr_test_sp + 1); --increment the stack pointer
			    next_test_sr(0) <= '1';
		
				elsif (internal_opcode = "00001001") then --SEI
			
					next_test_sr(0) <= '1';
					next_test_pc <= std_logic_vector(unsigned(curr_test_pc) + 1);
		
				elsif (internal_opcode = "00001010") then --CLI
			
					next_test_sr(0) <= '0';
					next_test_pc <= std_logic_vector(unsigned(curr_test_pc) + 1);
			
				end if;
				
			end if;
			
			if(rst = '1') then
				next_test_pc <= "001000";
			end if;
			
  end process;
  
    
end syn;
