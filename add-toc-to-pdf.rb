# -*- coding: utf-8 -*-
require 'pp'
require 'prawn'
require 'fileutils'

DEFAULT_BETSU_NOMBLE_START_NO = 1
DEFAULT_TOOSHI_NOMBLE_START_NO = 10

# コマンドラインの解析
def get_command_line_info
  toc_meta = {
    :betsu_nombre_start_no =>  DEFAULT_BETSU_NOMBLE_START_NO,
    :tooshi_nombre_start_no => DEFAULT_TOOSHI_NOMBLE_START_NO
  }

  opt = OptionParser.new
  opt.banner =<<"BANNER"
#{File.basename($0)} - tocファイルに記載されたページ番号(通しノンブルと別ノンブル)をPDFファイルの物理番号に変換する。

Usage: #{File.basename($0)} [options] toc_file original_pdf_file [pdf_file_with_toc]

   1番目の引数に目次ファイルのパス、
   2番目の引数に目次を付与したいPDFファイル、
   3番目の引数(オプション)に生成される目次が付与されたPDFファイルを指定する。
   3番目の引数が省略された場合は、2番目の引数のPDFファイル名の先頭に"toc_"を付与したPDFファイルを生成する。

BANNER

  # 別ノンブルの開始物理ページ番号
  opt.on("-b",
         "--betsu-start-no pageNo",
         Integer,
         "別ノンブルの開始物理ページ番号を指定する。(デフォルト値:#{ toc_meta[:betsu_nombre_start_no]})"
         ){|n|
    toc_meta[:betsu_nombre_start_no] = n
  }
  # 通しノンブルの開始物理ページ番号
  opt.on("-t",
         "--tooshi-start-no pageNo",
         Integer,
         "通しノンブルの開始物理ページ番号を指定する。(デフォルト値:#{ toc_meta[:tooshi_nombre_start_no]})"
         ){|n|
    toc_meta[:tooshi_nombre_start_no] = n
  }

  opt.parse!(ARGV)

  if ARGV.size == 0
    puts "エラー: 目次ファイルのパスを指定してください。"
    puts ""
    puts opt.help
    exit -1
  end

  if ARGV.size == 1
    puts "エラー: PDFファイルのパスを指定してください。"
    puts ""
    puts opt.help
    exit -1
  end

  if ARGV.size < 2
    puts "エラー: 目次ファイルとPDFファイルのパスを指定してください。"
    puts ""
    puts opt.help
    exit -1
  end

  unless File.exists?(File.expand_path(ARGV[0]))
    puts "エラー: 目次ファイル(#{ARGV[0]})が見つかりません。"
    puts ""
    puts opt.help
    exit -1
  end

  unless File.exists?(File.expand_path(ARGV[1]))
    puts "エラー: PDFファイル(#{ARGV[1]})が見つかりません。"
    puts ""
    puts opt.help
    exit -1
  end

  return toc_meta
end

def parse_line(line, meta)
  info = { :type => :no_page }
  line_data = line.chomp
  info[:line_data] = line_data
  if line_data =~ /^(.+)\t+\s*\(([0-9]+)\)/
    info[:type] = :betsu_no
    info[:toc_no] = $2.to_i
    info[:no] = info[:toc_no] + meta[:betsu_nombre_start_no] - 1
    info[:title] = $1
  elsif line_data =~ /^(.+)\t+\s*([0-9]+)/
    info[:type] = :tooshi_no
    info[:toc_no] = $2.to_i
    info[:no] = info[:toc_no] + meta[:tooshi_nombre_start_no] - 1
    info[:title] = $1
  end
  return info
end

def show_toc_with_pdf_no(toc_info)
  toc_info[:betsu_no].each do |line_info|
    puts "#{line_info[:title]}\t#{line_info[:no]}"
  end

  toc_info[:tooshi_no].each do |line_info|
    puts "#{line_info[:title]}\t#{line_info[:no]}"
  end
end

def setup_pdf_toc(toc_info, org_pdf_path, new_pdf_path)
  puts new_pdf_path
  dir_path = File.dirname(new_pdf_path)
  unless File.exists?(dir_path)
    FileUtils.mkdir_p(dir_path)
  end
  Prawn::Document.new(:template => org_pdf_path) do
    outline.define do
      toc_info[:betsu_no].each do |line_info|
        # puts "#{line_info[:title]}:#{line_info[:no]}"
        section(line_info[:title], :destination =>  line_info[:no])
      end

      toc_info[:tooshi_no].each do |line_info|
        # puts "#{line_info[:title]}:#{line_info[:no]}"
        section(line_info[:title], :destination =>  line_info[:no])
      end
    end
    render_file new_pdf_path
  end
end

def gen_new_pdf_path(org_path)
  dir_path = File.dirname(org_path)
  base_name = File.basename(org_path)
  return File.join(dir_path, "toc_#{base_name}")
end

# tocファイルに記載されたページ番号(通しノンブルと別ノンブル)をPDFファイルの目次に設定する。
if __FILE__ == $PROGRAM_NAME

  require 'optparse'

  # コマンドラインを解析する
  meta = get_command_line_info


  toc_path = ARGV.shift
  org_pdf_path = ARGV.shift
  new_pdf_path = ARGV.shift
  unless new_pdf_path
      new_pdf_path = gen_new_pdf_path(org_pdf_path)
  end

  toc_info = {
    :betsu_no => [],
    :tooshi_no => []
  }
  # tocファイルを読み込む
  File.open(File.expand_path(toc_path)) do |f|
    f.each do |line|
      # 空行は飛す
      next if line =~ /^\s*$/
      # コメント行は飛す
      next if line =~ /^\s*#/

      # 行末のページ番号を取得
      line_info = parse_line(line, meta)

      # ページ番号を分類
      #   ※ ページ番はDTPの用語でノンブル(nombre)という(らしい。wikipedia調べ。)。
      #     通しノンブル: 本文に使用されるページ番号
      #     別ノンブル: 序文や目次に使用されるページ番号
      if line_info[:type] == :no_page
        puts "warn #{line_info.inspect}"
      else
        toc_info[line_info[:type]] << line_info
      end
    end
  end

  #show_toc_with_pdf_no(toc_info)
  setup_pdf_toc(toc_info, org_pdf_path, new_pdf_path)
end
