require_relative "./shared/print_diff"
    include PrintDiff
    def define_options
      @parser.on "--cached", "--staged" do
        @options[:cached] = true
      if @options[:cached]