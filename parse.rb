require 'csv'
require 'settingslogic'

class Settings < Settingslogic
  source "./application.yaml"
  namespace 'csv'
end

def includeUntouchable(str)
  return str.match?(/〜|以下に|次に番地がくる場合/) ? true : false
end

def pickupFromEnumerable(e)
  # 現状対応できない表現、あるいは住所ではない表現の場合は
  # :street, :street_kana を削除する
  if includeUntouchable(e[:street])
    e[:street]      = ''
    e[:street_kana] = ''
  end

  [
    e[:postcode7],
    # e[:postcode5],
    e[:state],
    e[:city],
    e[:street],
    e[:state_kana],
    e[:city_kana],
    e[:street_kana],
    # e[:flg_multiple_postcode],
    # e[:flg_include_ban],
    # e[:flg_include_chome],
    # e[:flg_multiple_address],
    # e[:flg_changed],
    # e[:flg_why_changed],
  ]
end

postcodesTable = CSV.table(Settings.workingDir + Settings.file, headers: Settings.header, :converters => nil)

# CSVの全レコードを郵便番号(7桁)単位でマージする
#   1つの郵便番号に複数の市区町村(:city)が紐づく場合はそれぞれ別レコードとする
#   1つの郵便番号に複数の地区名(:street)が紐づく場合は一旦同一レコードにマージし、
#   後続処理でそれぞれ別レコードに分割する
mergedE = []
addressesByPostcode = postcodesTable.group_by{|row| row[:postcode7]}
addressesByPostcode.each { |postcode, group|
  # 郵便番号と住所が1:1の場合
  if group.length == 1
    group.each {|e| mergedE << e}
    next
  end

  # 郵便番号と住所が1:nの場合
  prevE  = ''
  finalE = ''
  group.each {|e|
    if prevE.empty? # 1行目は次行の比較用に確保
      prevE = e
      next
    end

    # 同じ郵便番号で複数の :city を含む場合がある
    if prevE[:city] != e[:city]
      # :city に差分がある場合は、直前に読み込んだレコードを結果に追加する
      mergedE << prevE
      prevE  = e # 次行の比較用に確保
      finalE = e # 最終行を読み落とす可能性があるので確保
      next
    end

    # 同じ郵便番号で複数の :street を含む場合がある
    # これは独立した住所表記である場合と、途中で分割され複数レコードになっている場合がある
    # この2種類を識別することは困難なため ' ' を区切り文字として :street を単純に連結する
    prevE[:street]      << ' ' + e[:street]
    prevE[:street_kana] << ' ' + e[:street_kana]
    finalE = prevE # 現在の初理行が最終行の可能性があるので確保
  }
  mergedE << finalE if !finalE.empty?
}

# 1レコード、1住所の形に変換する
results = []
mergedE.each {|e|
  # 暫定的に（）の記述は破棄する
  e[:street].gsub!(/（.*?）/, '')      if e[:street].match?(/（|）/)
  e[:street_kana].gsub!(/\(.*?\)/, '') if e[:street_kana].match?(/\(|\)/)

  # デリミタ(、)で分割されている記述を、複数行レコードのマージと同様に処理する
  e[:street].gsub!('、', ' ')
  e[:street_kana].gsub!('､', ' ')
  if e[:street].include?(' ')
    # ここまでの処理で（）で補足され記述を破棄しているため、
    # :street には同じ地名表記が重複しているケースが多数発生している
    # 例えばsplitの結果をuniqなど例えばとすれば重複排除になるが、
    # 異なる住所表記で同じ読みガナの場合に不適切な結果となるため、
    # この段階では敢えて重複を排除しない
    streets      = e[:street].split()
    streets_kana = e[:street_kana].split()

    # ToDo: :street と :street_kana の要素数に差分がある場合はエラーとする
    next if streets.count != streets_kana.count

    streets.zip(streets_kana) {|street, street_kana|
      # 現状対応できない表現、あるいは住所ではない表現の場合は
      # :street, :street_kana を削除する
      if includeUntouchable(street)
        street      = ''
        street_kana = ''
      end

      e[:street]      = street
      e[:street_kana] = street_kana
      results << pickupFromEnumerable(e)
    }
    next
  end

  # レコードの結合処理の関係でカナだけが余分に付与されている可能性があるため、
  # その場合には不要なカナ情報を削除する
  e[:street_kana].gsub!(/ .*/, '') if !e[:street].include?(' ') && e[:street_kana].include?(' ')

  results << pickupFromEnumerable(e)
}

# export by CSV
CSV.open(Settings.workingDir + Settings.outputFile, 'w') {|csv|
  results.each {|result| csv << result}
}
