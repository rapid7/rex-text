require 'spec_helper'


describe Rex::Text::Color do
  let(:dummy_class) {
    Class.new do
      include Rex::Text::Color

      def supports_color?
        true
      end
    end
  }
  subject(:dummy_shell) { dummy_class.new }


  describe '#ansi' do

    it 'should return the correct ANSI code for cyan' do
      expect(dummy_shell.ansi('cyan')).to eq "\e[36m"
    end

    it 'should return the correct ANSI code for dark red' do
      expect(dummy_shell.ansi('dark', 'red')).to eq "\e[2;31m"
    end

    it 'should return the correct ANSI code for underline' do
      expect(dummy_shell.ansi('underline')).to eq "\e[4m"
    end

    it 'should return the correct ANSI code for blink' do
      expect(dummy_shell.ansi('blink')).to eq "\e[5m"
    end

    it 'should return the correct ANSI code for bold' do
      expect(dummy_shell.ansi('bold')).to eq "\e[1m"
    end

    it 'should return the correct ANSI code for on_cyan' do
      expect(dummy_shell.ansi('on_cyan')).to eq "\e[46m"
    end
  end

  describe '#colorize' do

    it 'should call the ansi method if it supports color' do
      color = 'cyan'
      expect(dummy_shell).to receive(:ansi).with(color)
      dummy_shell.colorize(color)
    end

    it 'should return an emtpy string if it does not support color' do
      expect(dummy_shell).to receive(:supports_color?).and_return(false)
      expect(dummy_shell.colorize('cyan')).to eq ''
    end
  end

  describe '#do_colorize' do

    it 'should call the ansi method if it supports color' do
      color = 'cyan'
      expect(dummy_shell).to receive(:ansi).with(color)
      dummy_shell.do_colorize(color)
    end

    it 'should return an emtpy string if it does not support color' do
      expect(dummy_shell).to receive(:supports_color?).and_return(false)
      expect(dummy_shell.do_colorize('cyan')).to eq ''
    end
  end

  describe '#reset_color' do
    it 'calls colorize with the argument "clear"' do
      expect(dummy_shell).to receive(:colorize).with('clear')
      dummy_shell.reset_color
    end
  end

  describe '#substitute_colors' do
    context 'when not in a prompt' do
      it 'should replace "%cya" with the cyan ansi code' do
        expect(dummy_shell.substitute_colors("this is a %cyatest")).to eq "this is a \e[36mtest"
      end
    end

    context 'when in a prompt' do
      it 'should add the pre and post codes to the ANSI code' do
        expect(dummy_shell.substitute_colors("this is a %cyatest", true)).to eq "this is a \x01\e[36m\x02test"
      end
    end
  end

end
