module InformationHelper
  LIST = [
    %w(2019/08/28 ツイートクリーナーをリニューアルしました),
    %w(2019/03/28 凍結されている場合に分かりやすい表示にしました),
    %w(2019/03/26 設定画面を分かりやすくしました),
    %w(2019/03/25 表示の高速化を行いました),
    %w(2019/03/05 表示の高速化を行いました),
    %w(2019/02/25 オーディエンス分析機能が追加されました),
    %w(2019/02/18 ときめきアンフォロー機能を作りました),
    %w(2019/01/24 検索結果の並べ替えに対応しました),
    %w(2019/01/23 検索の高速化を行いました),
    %w(2019/01/19 リムられ通知のフォーマットを変更しました),
    %w(2019/01/18 ツイートの一括削除ができるようになりました),
    # %w(2019/01/17 リムられ通知を復活させました),
    # %w(2017/08/23 垢消しからの復活を分かるようにしました),
    # %w(2017/08/14 フォローボタンを動くようにしました),
    # %w(2017/08/11 削除されたアカウントが分かるようにしました),
    # %w(2017/08/02 ツイッター戦闘力分析を復活させました),
    # %w(2017/07/31 集計の高速化を行いました),
    # %w(2017/07/25 検索の精度を上げました),
    # %w(2017/03/29 集計の高速化を行いました),
    # %w(2017/03/22 表示の高速化を行いました),
  ].map(&:freeze)

  def information_list
    LIST
  end
end
