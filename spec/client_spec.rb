require 'spec_helper'

RSpec.describe Aws::Xray::Client do
  describe '#send_segment' do
    def build_server
      s = UDPSocket.new
      s.bind('127.0.0.1', 0)
      s
    end
    let(:segment) { double('segment', to_json: payload.to_json) }
    let(:payload) { { 'id' => 'abc' } }
    def wait
      Thread.pass
      sleep 0.01
      Thread.pass
    end

    # Because rspec changes `$stderr` to StringIO.
    let(:io) { StringIO.new }
    around do |ex|
      back = Aws::Xray.config.segment_sending_error_handler
      Aws::Xray.config.segment_sending_error_handler = Aws::Xray::DefaultErrorHandler.new(io)
      ex.run
      Aws::Xray.config.segment_sending_error_handler = back
    end

    context 'success case' do
      it 'sends given segment' do
        s = build_server
        allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: s.addr[1])

        Aws::Xray::Client.send_segment(segment); sleep 0.01;

        sent = s.recvfrom(1024)[0]
        expect(sent.split("\n").size).to eq(2)

        header, body = sent.split("\n").map {|e| JSON.parse(e) }
        expect(header).to eq('format' => 'json', 'version' => 1)
        expect(body).to eq(payload)
      end
    end

    # Note that fork(2) is not avaiable on some platforms like Windows and
    # NetBSD 4.
    if Process.respond_to?(:fork)
      context 'when fork(2) was called and executed in the child process' do
        it 'sends given segment' do
          s = build_server

          Process.fork do
            allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: s.addr[1])
            Aws::Xray::Client.send_segment(segment); sleep 0.01;
          end

          sent = Timeout.timeout(1) { s.recvfrom(1024)[0] }
          expect(sent.split("\n").size).to eq(2)

          header, body = sent.split("\n").map {|e| JSON.parse(e) }
          expect(header).to eq('format' => 'json', 'version' => 1)
          expect(body).to eq(payload)
        end
      end
    end

    context 'when too large payload is about to sent' do
      # Build as much as large payload to occur Errno::EMSGSIZE.
      # This is not platform compatible solution though...
      let(:payload) { { 'data' => 'abc' * 100000 } }

      it 'ignores system call erros' do
        s = build_server
        allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: s.addr[1])
        Aws::Xray::Client.send_segment(segment); wait;
        expect(io.tap(&:rewind).read).to match(/Failed to send a segment/)
      end
    end

    context 'when invalid port is specified' do
      before { allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: 0) }

      it 'ignores socket errors' do
        Aws::Xray::Client.send_segment(segment); wait;
        expect(io.tap(&:rewind).read).to match(/Failed to send a segment/)
      end
    end

    context 'when can not send all bytes' do
      let(:sock) { double('sock', close: nil) }
      before do
        allow(sock).to receive(:send).and_return(0)
        allow(Aws::Xray.config).to receive(:client_options).and_return(sock: sock)
      end

      it 'raises CanNotSendAllByteError' do
        Aws::Xray::Client.send_segment(segment); wait;
        expect(io.tap(&:rewind).read).to match(/Can not send all bytes/)
      end
    end

    context 'when queue is full' do
      before do
        allow(Aws::Xray::Worker.instance_variable_get('@queue')).to receive(:push).and_raise(ThreadError)
        allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: 0)
      end

      it 'raises QueueIsFullError' do
        Aws::Xray::Client.send_segment(segment); wait;
        expect(io.tap(&:rewind).read).to match(/The queue exceeds max size/)
      end
    end

    context 'when error handler raises errors' do
      around do |ex|
        back = Aws::Xray.config.segment_sending_error_handler
        Aws::Xray.config.segment_sending_error_handler = -> (*) { raise 'test error' }
        ex.run
        Aws::Xray.config.segment_sending_error_handler = back
      end
      before { allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: 0) }

      it 'rescues the error and log them' do
        expect {
          Aws::Xray::Client.send_segment(segment); wait;
        }.to output(/test error/).to_stderr
      end
    end

    context 'when error handler raises errors' do
      around do |ex|
        back = Aws::Xray.config.segment_sending_error_handler
        Aws::Xray.config.segment_sending_error_handler = Aws::Xray::ErrorHandlerWithSentry.new
        ex.run
        Aws::Xray.config.segment_sending_error_handler = back
      end
      before { allow(Aws::Xray.config).to receive(:client_options).and_return(host: '127.0.0.1', port: 0) }

      it 'does not do nothing' do
        expect {
          Aws::Xray::Client.send_segment(segment); wait;
        }.to output(/ErrorHandlerWithSentry is configured but `Raven` is undefined./).to_stderr
      end
    end
  end
end
