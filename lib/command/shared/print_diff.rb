    def define_print_diff_options
      @parser.on("-p", "-u", "--patch") { @options[:patch] = true  }
      @parser.on("-s", "--no-patch")    { @options[:patch] = false }
    end
