# -*- coding: utf-8 -*-
require 'fileutils'
require 'optparse'
require 'pp'
require 'prawn'
require 'prawn/templates'
require 'yaml'

DEFAULT_BETSU_NOMBLE_START_NO = 1
DEFAULT_TOOSHI_NOMBLE_START_NO = 10

# コマンドラインの解析
def get_command_line_info
  toc_meta = {
    :betsu_nombre_start_no =>  DEFAULT_BETSU_NOMBLE_START_NO,
    :tooshi_nombre_start_no => DEFAULT_TOOSHI_NOMBLE_START_NO,
    :toc_file => nil,
    :src_pdf => nil,
    :dst_pdf => nil
  }

  is_dump_config = false

  opt = OptionParser.new
  opt.banner =<<"BANNER"
#{File.basename($0)} - tocファイルに記載されたページ番号(通しノンブルと別ノンブル)を目次としてPDFファイルに設定します。

Usage: #{File.basename($0)} [options]
BANNER
 # 目次ファイル
  opt.on("-m",
         "--toc-file toc_file",
         String,
         "目次ファイルを指定する。"
         ){|f|
    toc_meta[:toc_file] = f
  }
  # ソースPDF
  opt.on("-s",
         "--src-pdf src_pdf",
         String,
         "元PDFファイルを指定する。"
         ){|f|
    toc_meta[:src_pdf] = f
  }
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
  # 変換結果PDF
  opt.on("-d",
         "--dst-pdf dst_pdf",
         String,
         "変換結果PDFファイルを指定する。(デフォルト値:toc_(ソースPDF名))"
         ){|f|
    toc_meta[:dst_pdf] = f
  }
  # 設定ファイル
  opt.on("-c",
         "--config config",
         String,
         "設定ファイルを指定する。"
         ){|f|
    toc_meta[:config] = f
  }
  # 設定ファイル
  opt.on("--dump-config",
         "現在指定されたオプションに該当する設定ファイルを出力する。"
         ){|b|
    is_dump_config = b
  }

  opt.parse!(ARGV)


  # 設定ファイルチェック
  if toc_meta[:config]
    # 設定ファイル読み込み
    config_path = File.expand_path(toc_meta[:config])

    unless File.exists?(config_path)
      puts "エラー:設定ファイル(#{toc_meta[:config]})が存在しません。"
      puts ""
      puts opt.help
      exit -1
    end
    config = YAML.load_file(config_path)

    # 設定ファイルの値をtoc_metaに設定
    toc_meta.keys.each do |sym|
      if config.key?(sym)
        toc_meta[sym] = config[sym]
      end
    end
  end


  unless toc_meta[:toc_file]
    puts "エラー: 目次ファイルのパスを指定してください。"
    puts ""
    puts opt.help
    exit -1
  end

  unless toc_meta[:src_pdf]
    puts "エラー: PDFファイルのパスを指定してください。"
    puts ""
    puts opt.help
    exit -1
  end

  unless File.exists?(File.expand_path(toc_meta[:toc_file]))
    puts "エラー: 目次ファイル(#{toc_meta[:toc_file]})が見つかりません。"
    puts ""
    puts opt.help
    exit -1
  end

  unless File.exists?(File.expand_path(toc_meta[:src_pdf]))
    puts "エラー: PDFファイル(#{toc_meta[:src_pdf]})が見つかりません。"
    puts ""
    puts opt.help
    exit -1
  end

  unless toc_meta[:dst_pdf]
    toc_meta[:dst_pdf] = gen_new_pdf_path(toc_meta[:src_pdf])
  end

  if is_dump_config
    toc_meta.delete(:config)
    puts YAML.dump(toc_meta)
    exit 0
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
  #puts new_pdf_path
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

  # コマンドラインを解析する
  meta = get_command_line_info


  toc_path = meta[:toc_file]
  org_pdf_path = meta[:src_pdf]
  new_pdf_path = meta[:dst_pdf]

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
