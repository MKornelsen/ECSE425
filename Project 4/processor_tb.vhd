LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE std.textio.ALL;
USE ieee.std_logic_textio.ALL;
USE work.register_pkg.ALL;

ENTITY processor_tb IS
END processor_tb;

ARCHITECTURE behavior OF processor_tb IS
    COMPONENT processor IS
        PORT (
            clock : IN std_logic;
            reset : IN std_logic;

            inst_addr : OUT std_logic_vector(31 DOWNTO 0);
            inst_read : OUT std_logic;
            inst_readdata : IN std_logic_vector(31 DOWNTO 0);
            inst_waitrequest : IN std_logic;

            data_addr : OUT std_logic_vector(31 DOWNTO 0);
            data_read : OUT std_logic;
            data_readdata : IN std_logic_vector(31 DOWNTO 0);
            data_write : OUT std_logic;
            data_writedata : OUT std_logic_vector(31 DOWNTO 0);
            data_waitrequest : IN std_logic;

            register_output : OUT t_register_bank
        );
    END COMPONENT;

    COMPONENT cache IS
        GENERIC (
            ram_size : INTEGER := 32768
        );
        PORT (
            clock : IN std_logic;
            reset : IN std_logic;

            -- Avalon interface --
            s_addr : IN std_logic_vector (31 DOWNTO 0);
            s_read : IN std_logic;
            s_readdata : OUT std_logic_vector (31 DOWNTO 0);
            s_write : IN std_logic;
            s_writedata : IN std_logic_vector (31 DOWNTO 0);
            s_waitrequest : OUT std_logic;

            m_addr : OUT INTEGER RANGE 0 TO ram_size - 1;
            m_read : OUT std_logic;
            m_readdata : IN std_logic_vector (7 DOWNTO 0);
            m_write : OUT std_logic;
            m_writedata : OUT std_logic_vector (7 DOWNTO 0);
            m_waitrequest : IN std_logic
        );
    END COMPONENT;

    COMPONENT memory IS
        GENERIC (
            ram_size : INTEGER := 32768;
            mem_delay : TIME := 1 ns;
            clock_period : TIME := 1 ns
        );
        PORT (
            clock : IN STD_LOGIC;
            writedata : IN STD_LOGIC_VECTOR (7 DOWNTO 0);
            address : IN INTEGER RANGE 0 TO ram_size - 1;
            memwrite : IN STD_LOGIC;
            memread : IN STD_LOGIC;
            readdata : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
            waitrequest : OUT STD_LOGIC
        );
    END COMPONENT;

    COMPONENT bmux IS 
    PORT (
        a : IN std_logic;
        b : IN std_logic;
        sel : IN std_logic;
        x : OUT std_logic
        );
    END COMPONENT;

    COMPONENT vmux IS
    PORT (
        a : IN std_logic_vector(31 DOWNTO 0);
        b : IN std_logic_vector(31 DOWNTO 0);
        sel : IN std_logic;
        x : OUT std_logic_vector(31 DOWNTO 0)
        );
    END COMPONENT;

    --test signals 
    SIGNAL rst_processor : std_logic := '0';
    SIGNAL rst_cache : std_logic := '0';
    SIGNAL clk : std_logic := '0';
    CONSTANT clk_period : TIME := 1 ns;
    SIGNAL register_sigs : t_register_bank;

    --processor and instruction cache signals
    SIGNAL p2ic_addr : std_logic_vector (31 DOWNTO 0);
    SIGNAL p2ic_read : std_logic;
    SIGNAL ic2p_readdata : std_logic_vector (31 DOWNTO 0);
    SIGNAL ic2p_waitrequest : std_logic;

    --processor and data cache signals
    SIGNAL p2dc_addr : std_logic_vector (31 DOWNTO 0);
    SIGNAL p2dc_read : std_logic;
    SIGNAL dc2p_readdata : std_logic_vector (31 DOWNTO 0);
    SIGNAL p2dc_write : std_logic;
    SIGNAL p2dc_writedata : std_logic_vector (31 DOWNTO 0);
    SIGNAL dc2p_waitrequest : std_logic;

    --instruction cache and instruction memory signals
    SIGNAL ic2m_addr : INTEGER RANGE 0 TO 2147483647;
    SIGNAL ic2m_read : std_logic;
    SIGNAL m2ic_readdata : std_logic_vector (7 DOWNTO 0);
    SIGNAL ic2m_write : std_logic;
    SIGNAL ic2m_writedata : std_logic_vector (7 DOWNTO 0);
    SIGNAL m2ic_waitrequest : std_logic;

    --data cache and instruction memory signals
    SIGNAL dc2m_addr : INTEGER RANGE 0 TO 2147483647;
    SIGNAL dc2m_read : std_logic;
    SIGNAL m2dc_readdata : std_logic_vector (7 DOWNTO 0);
    SIGNAL dc2m_write : std_logic;
    SIGNAL dc2m_writedata : std_logic_vector (7 DOWNTO 0);
    SIGNAL m2dc_waitrequest : std_logic;

    --memory IO signals
    -- SIGNAL input2im_addr: INTEGER RANGE 0 TO 2147483647;
    SIGNAL init_ic_addr: std_logic_vector(31 DOWNTO 0);

    -- SIGNAL input2dm_addr: INTEGER RANGE 0 TO 2147483647;
    SIGNAL final_dc_addr: std_logic_vector(31 DOWNTO 0);

    -- SIGNAL input2im_write: std_logic;
    SIGNAL init_ic_write: std_logic;

    -- SIGNAL input2im_writedata: std_logic_vector(7 downto 0);
    SIGNAL init_ic_writedata: std_logic_vector(31 downto 0);

    -- SIGNAL input2dm_read: std_logic;
    SIGNAL final_dc_read: std_logic;

    -- SIGNAL input2dm_readdata: std_logic_vector(7 downto 0);
    -- SIGNAL final_dc_readdata: std_logic_vector(31 downto 0);

    SIGNAL ic_addr : std_logic_vector(31 downto 0);
    SIGNAL ic_writedata : std_logic_vector(31 DOWNTO 0);
    SIGNAL ic_write : std_logic;

    SIGNAL dc_addr : std_logic_vector(31 DOWNTO 0);
    -- SIGNAL dc_readdata : std_logic_vector(31 DOWNTO 0);
    SIGNAL dc_read : std_logic;

    SIGNAL selector : std_logic;

BEGIN

    dut : processor
    PORT MAP(
        clock => clk,
        reset => rst_processor,

        inst_addr => p2ic_addr,
        inst_read => p2ic_read,
        inst_readdata => ic2p_readdata,
        inst_waitrequest => ic2p_waitrequest,

        data_addr => p2dc_addr,
        data_read => p2dc_read,
        data_readdata => dc2p_readdata,
        data_write => p2dc_write,
        data_writedata => p2dc_writedata,
        data_waitrequest => dc2p_waitrequest,
        
        register_output => register_sigs
    );

    incache : cache
    PORT MAP(
        clock => clk,
        reset => rst_cache,

        s_addr => ic_addr,
        s_read => p2ic_read,
        s_readdata => ic2p_readdata,
        s_write => ic_write,
        s_writedata => ic_writedata,
        s_waitrequest => ic2p_waitrequest,

        m_addr => ic2m_addr,
        m_read => ic2m_read,
        m_readdata => m2ic_readdata,
        m_write => ic2m_write,
        m_writedata => ic2m_writedata,
        m_waitrequest => m2ic_waitrequest
    );

    inmem : memory
    PORT MAP(
        clock => clk,
        writedata => ic2m_writedata,
        address => ic2m_addr,
        --address => ic2m_addr,
        memwrite => ic2m_write,
        memread => ic2m_read,
        readdata => m2ic_readdata,
        waitrequest => m2ic_waitrequest
    );

    datcache : cache
    PORT MAP(
        clock => clk,
        reset => rst_cache,

        s_addr => dc_addr,
        s_read => dc_read,
        s_readdata => dc2p_readdata,
        s_write => p2dc_write,
        s_writedata => p2dc_writedata,
        s_waitrequest => dc2p_waitrequest,

        m_addr => dc2m_addr,
        m_read => dc2m_read,
        m_readdata => m2dc_readdata,
        m_write => dc2m_write,
        m_writedata => dc2m_writedata,
        m_waitrequest => m2dc_waitrequest
    );

    datmemory : memory
    PORT MAP(
        clock => clk,
        writedata => dc2m_writedata,
        address => dc2m_addr,
        --address => dc2m_addr,
        memwrite => dc2m_write,
        memread => dc2m_read,
        readdata => m2dc_readdata,
        waitrequest => m2dc_waitrequest
    );

    icache_addr_mux : vmux
    PORT MAP(
        a => p2ic_addr,
        b => init_ic_addr,
        sel => selector,
        x => ic_addr
    );

    icache_data_mux : vmux
    PORT MAP (
        a => ic2p_readdata,
        b => init_ic_writedata,
        sel => selector,
        x => ic_writedata
    );

    icache_write_mux : bmux
    PORT MAP (
        a => '0',
        b => init_ic_write,
        sel => selector,
        x => ic_write
    );

    dcache_addr_mux : vmux
    PORT MAP(
        a => p2dc_addr,
        b => final_dc_addr,
        sel => selector,
        x => dc_addr
    );

    dcache_read_mux : bmux
    PORT MAP (
        a => p2dc_read,
        b => final_dc_read,
        sel => selector,
        x => dc_read
    );
    

    clk_process : PROCESS
    BEGIN
        clk <= '0';
        WAIT FOR clk_period/2;
        clk <= '1';
        WAIT FOR clk_period/2;
    END PROCESS;

    test_process : PROCESS
        CONSTANT filename : STRING := "Assembler/program.txt"; -- use more than once
        FILE file_pointer : text;
        FILE file_RESULTS: text;
        FILE file_registers: text;
        VARIABLE line_content : std_logic_vector (31 downto 0);
        VARIABLE line_input : line;
        VARIABLE filestatus : file_open_status;
        VARIABLE line_number : Integer;

        variable v_OLINE     : line;
        constant c_WIDTH : natural := 32;
        Variable outputline : std_logic_vector (31 downto 0);
    BEGIN
        wait for clk_period;
        selector <='1';
        --imem_addr<=input2im_addr;
        --dmem_addr<=input2dm_addr;

        --im_write<=input2im_write;
        --im_writedata<=input2im_writedata;

        -- dm_read<= '0';
        -- m2dc_readdata<= (others=> '0');
        --dm_readdata<=input2dm_readdata;

        rst_processor <= '1';
        rst_cache <= '1';
        line_number :=0;
        --read from binary into and place into in cache
        file_open (filestatus, file_pointer, filename, READ_MODE);
        file_open(file_RESULTS, "memory.txt", write_mode);
        file_open(file_registers, "register_file.txt", write_mode);
        
        REPORT filename & LF & HT & "file_open_status = " & file_open_status'image(filestatus);
        ASSERT filestatus = OPEN_OK REPORT "file_open_status /= file_ok" SEVERITY FAILURE; -- end simulation

        WAIT FOR clk_period * 2;
        rst_cache <= '0';
        
        WHILE NOT ENDFILE (file_pointer) LOOP
            wait for clk_period;
            --WAIT UNTIL falling_edge(clk); -- once per clock
            readline (file_pointer, line_input);
            REPORT line_input.all;
            read (line_input, line_content);
            
            -- init_ic_addr <= std_logic_vector(to_unsigned(line_number*4));
            -- init_ic_writedata <= line_content (7 downto 0);
            -- init_ic_write<='1';
            
            -- wait until rising_edge(ic2p_waitrequest);
            -- init_ic_write<='0';
            
            -- wait for clk_period;
            -- init_ic_addr <=  std_logic_vector(to_unsigned(line_number*4+1));
            -- init_ic_writedata <= line_content (15 downto 8);
            -- init_ic_write<='1';
            
            -- wait until rising_edge(ic2p_waitrequest);
            -- init_ic_write<='0';

            -- wait for clk_period;
            -- init_ic_addr <=  std_logic_vector(to_unsigned(line_number*4+2));
            -- init_ic_writedata <= line_content (23 downto 16);
            -- init_ic_write<='1';
           
            -- wait until rising_edge(ic2p_waitrequest);
            -- init_ic_write<='0';
            
            -- wait for clk_period;
            -- init_ic_addr <=  std_logic_vector(to_unsigned(line_number*4+3));
            -- init_ic_writedata <= line_content (31 downto 24);
            
            init_ic_writedata <= line_content;
            init_ic_write<='1';
            init_ic_addr <= std_logic_vector(to_unsigned(line_number * 4, 32));

            wait until rising_edge(ic2p_waitrequest);
            init_ic_write<='0';
            
            wait for clk_period;
            line_number:= line_number + 1;
        END LOOP;

        WAIT UNTIL falling_edge(clk); -- the last datum can be used first
        file_close (file_pointer);
        REPORT filename & " closed.";

        --execute
        selector <='0';
        WAIT FOR clk_period * 2;
        --imem_addr<=ic2m_addr;
        --dmem_addr<=dc2m_addr;

        --im_write<=ic2m_write;
        --im_writedata<=ic2m_writedata;

        --dm_read<= dc2m_read;
        --m2dc_readdata<= dm_readdata;
        REPORT "Begin Execution";
        rst_processor <= '0';
        --wait for clk_period*10000;
        for I in 0 to 10000 loop
            -- imem_addr<=ic2m_addr;
            -- dmem_addr<=dc2m_addr;
            --im_write<=ic2m_write;
            --im_writedata<=ic2m_writedata;

            --dm_read<= dc2m_read;
            --m2dc_readdata<= dm_readdata;
            wait until rising_edge(clk);
        end loop;

        REPORT "End Execution";
        --output
        selector <='1';
        --im_write<=input2im_write;
        --im_writedata<=input2im_writedata;

        --dm_read<='0';
        --dm_read<= input2dm_read;
        --m2dc_readdata<= (others=> '0');
        
        FOR I IN 0 TO 31 LOOP
            write(v_OLINE, register_sigs(I), right, c_WIDTH);
            writeline(file_registers, v_OLINE);
        END LOOP;

        rst_processor <= '1';
        
        for I in 0 to 4095 loop
            WAIT UNTIL falling_edge(clk); -- once per clock
            final_dc_addr <=  std_logic_vector(to_unsigned(I*4, 32));
            final_dc_read <='1';
            
            
            wait until rising_edge(dc2p_waitrequest);
            outputline := dc2p_readdata;
            final_dc_read <='0';
            
            write(v_OLINE, outputline, right, c_WIDTH);
            writeline(file_RESULTS, v_OLINE);
        end loop;
        
        WAIT UNTIL falling_edge(clk); 
        file_close (file_RESULTS);
        file_close(file_registers);
        REPORT "memory.txt closed.";
        wait;
    END PROCESS;

END;