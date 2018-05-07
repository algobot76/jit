  def commit_file(message, time = nil)
    commit message, time
  end

  def commit_tree(message, files)
    files.each do |path, contents|
      write_file path, contents
    end
    jit_cmd "add", "."
    it "prints a log starting from a specified commit" do
      jit_cmd "log", "--pretty=oneline", "@^"

      assert_stdout <<~LOGS
        #{ @commits[1].oid } B
        #{ @commits[2].oid } A
      LOGS
    end


    it "prints a log with patches" do
      jit_cmd "log", "--pretty=oneline", "--patch"

      assert_stdout <<~LOGS
        #{ @commits[0].oid } C
        diff --git a/file.txt b/file.txt
        index 7371f47..96d80cd 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -B
        +C
        #{ @commits[1].oid } B
        diff --git a/file.txt b/file.txt
        index 8c7e5a6..7371f47 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,1 +1,1 @@
        -A
        +B
        #{ @commits[2].oid } A
        diff --git a/file.txt b/file.txt
        new file mode 100644
        index 0000000..8c7e5a6
        --- /dev/null
        +++ b/file.txt
        @@ -0,0 +1,1 @@
        +A
      LOGS
    end
  end

  describe "with commits changing different files" do
    before do
      commit_tree "first",
        "a/1.txt"   => "1",
        "b/c/2.txt" => "2"

      commit_tree "second",
        "a/1.txt" => "10",
        "b/3.txt" => "3"

      commit_tree "third",
        "b/c/2.txt" => "4"

      @commits = ["@^^", "@^", "@"].map { |rev| load_commit(rev) }
    end

    it "logs commits that change a file" do
      jit_cmd "log", "--pretty=oneline", "a/1.txt"

      assert_stdout <<~LOGS
        #{ @commits[1].oid } second
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits that change a directory" do
      jit_cmd "log", "--pretty=oneline", "b"

      assert_stdout <<~LOGS
        #{ @commits[2].oid } third
        #{ @commits[1].oid } second
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits that change a nested directory" do
      jit_cmd "log", "--pretty=oneline", "b/c"

      assert_stdout <<~LOGS
        #{ @commits[2].oid } third
        #{ @commits[0].oid } first
      LOGS
    end

    it "logs commits with patches for selected files" do
      jit_cmd "log", "--pretty=oneline", "--patch", "a/1.txt"

      assert_stdout <<~LOGS
        #{ @commits[1].oid } second
        diff --git a/a/1.txt b/a/1.txt
        index 56a6051..9a03714 100644
        --- a/a/1.txt
        +++ b/a/1.txt
        @@ -1,1 +1,1 @@
        -1
        +10
        #{ @commits[0].oid } first
        diff --git a/a/1.txt b/a/1.txt
        new file mode 100644
        index 0000000..56a6051
        --- /dev/null
        +++ b/a/1.txt
        @@ -0,0 +1,1 @@
        +1
      LOGS
    end
  end

  describe "with a tree of commits" do

    #  m1  m2  m3
    #   o---o---o [master]
    #        \
    #         o---o---o---o [topic]
    #        t1  t2  t3  t4

    before do
      (1..3).each { |n| commit_file "master-#{n}" }

      jit_cmd "branch", "topic", "master^"
      jit_cmd "checkout", "topic"

      @branch_time = Time.now + 10
      (1..4).each { |n| commit_file "topic-#{n}", @branch_time }

      @master = (0..2).map { |n| resolve_revision("master~#{n}") }
      @topic  = (0..3).map { |n| resolve_revision("topic~#{n}") }
    end

    it "logs the combined history of multiple branches" do
      jit_cmd "log", "--pretty=oneline", "--decorate=short", "master", "topic"

      assert_stdout <<~LOGS
        #{ @topic[0]  } (HEAD -> topic) topic-4
        #{ @topic[1]  } topic-3
        #{ @topic[2]  } topic-2
        #{ @topic[3]  } topic-1
        #{ @master[0] } (master) master-3
        #{ @master[1] } master-2
        #{ @master[2] } master-1
      LOGS
    end

    it "logs the difference from one one branch to another" do
      jit_cmd "log", "--pretty=oneline", "master..topic"

      assert_stdout <<~LOGS
        #{ @topic[0] } topic-4
        #{ @topic[1] } topic-3
        #{ @topic[2] } topic-2
        #{ @topic[3] } topic-1
      LOGS

      jit_cmd "log", "--pretty=oneline", "master", "^topic"

      assert_stdout <<~LOGS
        #{ @master[0] } master-3
      LOGS
    end

    it "excludes a long branch when commit times are equal" do
      jit_cmd "branch", "side", "topic^^"
      jit_cmd "checkout", "side"

      (1..10).each { |n| commit_file "side-#{n}", @branch_time }

      jit_cmd "log", "--pretty=oneline", "side..topic", "^master"

      assert_stdout <<~LOGS
        #{ @topic[0] } topic-4
        #{ @topic[1] } topic-3
      LOGS
    end

    it "logs the last few commits on a branch" do
      jit_cmd "log", "--pretty=oneline", "@~3.."

      assert_stdout <<~LOGS
        #{ @topic[0] } topic-4
        #{ @topic[1] } topic-3
        #{ @topic[2] } topic-2
      LOGS
    end