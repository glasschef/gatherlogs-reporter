RSpec.describe Gatherlogs::CLI do
  let(:cli) do
    Gatherlogs::CLI.new({})
  end

  it 'should call show_versions if cli flag is set' do
    expect(cli).to receive(:version?) { true }
    expect(cli).to receive(:show_versions)

    cli.execute
  end

  it 'should call generate_report if no flag are set' do
    expect(cli).to receive(:generate_report)

    cli.execute
  end

  it 'should setup a new reporter' do
    expect(Gatherlogs::Reporter).to receive(:new).with(min_impact: nil, show_all_controls: nil, show_all_tests: nil)
    cli.reporter
  end

  it 'should call out to product.detect with the log path' do
    allow(Gatherlogs::Product).to receive(:detect).with('foo') { 'chef-server' }

    expect(cli.detect_product('foo')).to eq 'chef-server'
  end

  context 'setup log level' do
    it 'should set log level to debug' do
      expect(cli).to receive(:debug?) { true }

      cli.parse_args
      expect(Gatherlogs.logger.level).to eq Logger::DEBUG
    end

    it 'should set log level to error' do
      expect(cli).to receive(:quiet?) { true }

      cli.parse_args
      expect(Gatherlogs.logger.level).to eq Logger::ERROR
    end

    it 'should set log level to info' do
      cli.parse_args
      expect(Gatherlogs.logger.level).to eq Logger::INFO
    end
  end

  it 'should call disable_colors if monochrome is set' do
    expect(cli).to receive(:monochrome?) { true }

    expect(cli).to receive(:disable_colors)
    cli.parse_args
  end

  it 'should run inspec' do
    expect(cli).to receive(:find_profile_path).with('chef-server') { 'chef-server-profile' }
    runner = double('runner')
    expect(runner).to receive(:add_target).with('chef-server-profile')
    expect(runner).to receive(:run)
    expect(runner).to receive(:report) { { 'test' => 'bar' } }
    expect(cli).to receive(:inspec_runner).exactly(3).times.and_return(runner)

    expect(cli.inspec_exec('.', 'chef-server')).to eq('test' => 'bar')
  end

  it 'should extract files' do
    expect(Dir).to receive(:mktmpdir) { 'somepath' }
    expect(cli).to receive(:shellout!).with(
      [
        'tar', 'xvf', 'abc.gz', '-C', 'somepath', '--strip-components', '2'
      ]
    )
    expect(cli).to receive(:shellout!).with(
      "find 'somepath' -type d -exec chmod 755 {} \\;"
    )
    expect(cli).to receive(:shellout!).with(
      "find 'somepath' -type f -exec chmod 644 {} \\;"
    )

    cli.extract_bundle('abc.gz')
  end

  it 'should not try to fetch files if no url is given' do
    expect(cli.fetch_remote_tar(nil)).to be_nil
  end

  it 'should create a tempfile for the download' do
    expect(Tempfile).to receive(:new).with('gatherlogs') {
      double('tempfile', path: '/foo/gatherlogs.0123.gz', close: true)
    }
    expect(cli).to receive(:shellout!).with(
      [
        'wget', 'http://test.test', '-O', '/foo/gatherlogs.0123.gz'
      ]
    )

    expect(cli.fetch_remote_tar('http://test.test')).to eq '/foo/gatherlogs.0123.gz'
  end

  context 'printing reports' do
    let(:test_array_report) do
      "
testing
--------------------------------------------------------------------------------
test
"
    end

    let(:test_hash_report) do
      "
hash
----------
  bag: box
green: no
----------
"
    end

    it 'should return nil if there is no report to print' do
      expect(cli.print_report('test', '')).to eq nil
    end

    it 'should print a report from an array' do
      expect do
        cli.print_report('testing', ['test'])
      end.to output(test_array_report).to_stdout
    end

    it 'should print a report from a hash' do
      expect do
        cli.print_report('hash', 'bag': 'box', 'green': 'no')
      end.to output(test_hash_report).to_stdout
    end
  end
end
