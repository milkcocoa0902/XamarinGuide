# Xamarinってなぁに
はい，いきなりサブタイ回収しました．  
Xamarinっていうのは，Androidなら`Java`もしくは`Kotlin`のコードを，iOSなら`Swift`のコードをラッピングして`C#`を用いて開発することのできるフレームワークです.  
こいつを使うことで，各OS間でのロジックに関するコードを共通化することができるってわけなんですね．

さらにさらに，(ちょいと制限があるけど)UIすらも共通化することも可能です．

とりあえず実際にアプリをいくつか作っていきながらXamarinでの開発に慣れていきましょうね．  
そうそう，今回はAndroidアプリに関してのみ触れたいと思います．

そうそう，本著ではXamarinの導入方法とかプロジェクトの作成方法は解説しないことにします．  
めんどくさいんだもん．

# キッチンタイマー
まず手始めに定番とも言えるキッチンタイマーを作ってみましょう．  
キッチンタイマーにはどのような機能が必要でしょうか．

- タイマーをスタートする
- 終了時に知らせる

本当に最低限の要求仕様はこのくらいではないでしょうか.  
てことで開発に移っていきましょう！

## レイアウトを実装する
まずは，アプリのレイアウトを決めましょう．プロジェクトを作成した時に`activity_main.xml`というファイルが作成されると思うので，そちらをいじっていきましょう．  
ここはシンプルに`TextView`と`Button`でいこうではありませんか. 

```activity_main.xml:xml
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout
 xmlns:android="http://schemas.android.com/apk/res/android"
 xmlns:app="http://schemas.android.com/apk/res-auto"
 xmlns:tools="http://schemas.android.com/tools"
 android:layout_width="match_parent"
 android:layout_height="match_parent">
 <TextView
  android:layout_width="wrap_content"
  android:layout_height="wrap_content"
  android:id="@+id/remains"
  android:textAppearance="?android:attr/textAppearanceLarge"
  android:textSize="80sp"
  android:text="03:00"
  android:layout_centerInParent="true"
  />
 <Button
  android:layout_width="wrap_content"
  android:layout_height="wrap_content"
  android:id="@+id/start"
  android:text="start"
  android:layout_below="@id/remains"
  android:layout_centerHorizontal="true"/>
</RelativeLayout>
```

## プログラムを書いていこう
最低限キッチンタイマー的な動作をするプログラムを書いて見ましょう．．  
先ほどの要件定義を満たすために，カウントダウン機構とスタート動作，ビープ音の生成・発音機能を実装していくことにします．


```MainActivity.cs:CS
using Android.App;
using Android.Media;
using Android.OS;
using Android.Support.V7.App;
using Android.Widget;

namespace KitchenTimer {
 [Activity(Label = "@string/app_name", Theme = "@style/AppTheme.NoActionBar", MainLauncher = true)]
 public class MainActivity : AppCompatActivity {

  // 残り秒数
  private int sec_ = 180;
  private int cnt_;

  Handler handler_;
  TextView tv_;
  AudioTrack audio_;

  // Beep音用の変数群
  const double amplification_ = 0.4;
  const int sampleRate_ = 44100; // [samples / sec]
  const short bitRate_ = 16; // [bits / sec]
  const short freq_ = 440; // [Hz] = [1 / sec]
  const double duration_ = 0.5; // [sec]
  short[] audioBuf_;

  protected override void OnCreate(Bundle savedInstanceState) {
   base.OnCreate(savedInstanceState);
   Xamarin.Essentials.Platform.Init(this, savedInstanceState);
   SetContentView(Resource.Layout.activity_main);

   handler_ = new Handler();

   // (1)
   // 時間を表示させるviewの取得
   tv_ = FindViewById<TextView>(Resource.Id.remains);

   // (2)
   // Buttonのクリック動作を設定
   // どうせ保持していても使わないので直接構築
   // 1000ミリ秒経過後にタスクを実行するように設定しているぞ
   FindViewById<Button>(Resource.Id.start)
    .Click += (sender, e) => {
     cnt_ = sec_;
     handler_.PostDelayed(() => Action(), 1000);
     ((Button)sender).Enabled = false;
    };

  /// @brief : Resume時に呼び出されるhook
  /// @return : None
  protected override void OnResume() {
   base.OnResume();

   // [samples / sec] * [sec] = [samples]
   int samples = (int)(sampleRate_ * duration_); 
   audioBuf_ = new short[samples];

   // (3)
   // Beep音の生成
   for(int point = 0;point < samples;point++) {
    // pointの最大値はsamplesと同値．すなわち発音時間でのsample数
    // すなわち，point / sampleRate_は時間位置(time / freq)と等価的存在
    audioBuf_[point] = (short)((amplification_ * short.MaxValue) *
     System.Math.Sin(2.0 * System.Math.PI * freq_ * point / sampleRate_));
   }

   audio_ = new AudioTrack(Stream.Music,
               sampleRate_,
               ChannelOut.Mono,
               Encoding.Pcm16bit,
               audioBuf_.Length * bitRate_ / 8,
               AudioTrackMode.Static);
   audio_.Write(audioBuf_, 0, audioBuf_.Length);
  }


  // (4)
  /// @brief : 一定時間ごとに行うタスク
  /// @return : None
  void Action() {
   handler_.RemoveCallbacksAndMessages(null);
   cnt_--;

   if(cnt_ > 0)
    handler_.PostDelayed(Action, 1000);
   else
    Beep();

   // (5)
   // この関数が別スレッドで動いているので，
   // UIスレッドを明示的に指定
   RunOnUiThread(() => {
    tv_.Text = (cnt_ / 60).ToString("D2") +
    ":" +
    (cnt_ % 60).ToString("D2");
   });
  }

  ///  @brief  : Beep音を鳴らす
  ///  @return : None
  void Beep() {
   audio_.Stop();
   audio_.ReloadStaticData();
   audio_.Play();
  }
 }
}
```

**(1)**, **(2)** ではそれぞれのコントロールを取得してます．  
両者を比べてみれば一目瞭然ですが，**(1)** ではインスタンスを生成しているのに対して **(2)** では，生成せずに直接操作をしてます．  
別に，以降もそのコントロールを使用するなら保存しておけばいいですし，その場限りでしか操作しないなら直接構築してあげればいいかなと思います．  
そしてそして，**Xamarinでは，コントロールのアクションはラムダ式で登録できる** のです！！！  
あと，二重，三重にボタンを押してしまわないようにスタートしたらクリックできないようにしてしまおう．  

**(3)** では，カウント終了時に鳴らす音声を生成しています．  
思いっきり高校物理の波動の分野ですね．覚えてますか？？笑  

**(4)** の`Action`という関数は，ボタンクリック時に1000[ms]遅延で実行するタスク，つまりタイマーカウントを担っています，遅延動作をネストしたかったのでわざわざ関数化しました．  

**(5)** の部分は，タイマーの残り時間をフォアグラウンドで実行するためのコードです．`RunOnUiThread()`を用いる事で，UIの更新をスレッドセーフ(?)に行うことができるのです．  

さて，これだけで本当に簡単なキッチンタイマーができてしまいました．  
しかしながらこれでは，スタートしてカウント終了したらそれっきりです．これでは使い物になりませんよね．  
て事で，こいつに機能をじゃんじゃん追加していって本格的なキッチンタイマーを作っていくこととしましょう．  

## 機能を追加する
### リセット機能
とりあえず，タイマーが終了したら再度使えるようにリセットしたいのでリセット機能を追加してみましょう．  
まずはレイアウトをいじります．

```activity_main.xml:xml
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout
 xmlns:android="http://schemas.android.com/apk/res/android"
 xmlns:app="http://schemas.android.com/apk/res-auto"
 xmlns:tools="http://schemas.android.com/tools"
 android:layout_width="match_parent"
 android:layout_height="match_parent">
 <TextView
  android:layout_width="wrap_content"
  android:layout_height="wrap_content"
  android:id="@+id/remains"
  android:textAppearance="?android:attr/textAppearanceLarge"
  android:textSize="80sp"
  android:text="03:00"
  android:layout_centerInParent="true"
  />
 <RelativeLayout
  android:layout_width="wrap_content"
  android:layout_height="wrap_content"
  android:layout_below="@id/remains"
  android:layout_centerHorizontal="true"
  android:id="@+id/buttonGroup">

  <Button
   android:layout_width="wrap_content"
   android:layout_height="wrap_content"
   android:id="@+id/start"
   android:text="start"/>
  <Button
   android:layout_width="wrap_content"
   android:layout_height="wrap_content"
   android:id="@+id/reset"
   android:text="reset"
   android:layout_toRightOf="@id/start"/>
 </RelativeLayout>
</RelativeLayout>
```

ここで，キモかどうかはちょっと微妙ですが，ボタンとボタンの間を画面の中心に合わせたいので`RelativeLayout`でラッピングしています.

そして，追加したリセットボタンのコントロールを取得して動作を定義しましょう．今回のリセットは，タイマーをストップしてカウントを初期値に戻すこととします．  

```MainActivity.cs:CS
   // (1)
   // startボタンのコントロールは保持
   var start = FindViewById<Button>(Resource.Id.start);
   start.Click += (sender, e) => {
    cnt_ = sec_;
    handler_.PostDelayed(() => Action(), 1000);
    ((Button)sender).Enabled = false;
   };

   // (2)
   // resetボタンのコントロールは一時的
   FindViewById<Button>(Resource.Id.reset)
    .Click += (sender, e) => {
     // (3)
     // カウントタスクをリセット
     handler_.RemoveCallbacksAndMessages(null);
     cnt_ = sec_;

     RunOnUiThread(() => {
      tv_.Text = (sec_ / 60).ToString("D2") +
      ":" +
      (sec_ % 60).ToString("D2");
     });
     start.Enabled = true;
    };
```

さて，コードを見ていきましょう．  

**(1)** では，先ほどの時点では保持していなかったstartボタンへのコントロールを保持するようにしています．というのも，リセット時にstartボタンをクリック可能にするためにアクセスする必要があり，その度にコントロールを獲得していたら効率が悪いからです．  

対して **(2)** ではリセットボタンのコントロールを保持していません．別にリセットボタンは他のボタンとかに左右されないので．  

**(3)** では，startボタンで再帰的に登録されたカウントダウンタイマーの登録解除をしています．  

これだけの変更で，タイマーをリセットすることができました．  
簡単ですね．

### 任意の時間を指定
次に加えたい機能は，計測時間を任意のものにすることです．  
現在は3分決め打ちなのでラーメンタイマーにしかなりません，別にそれでもいいって人もいるでしょうが，ちょっと用途が限定的すぎますね．  

時間を表示させる部分のUIを以下のように2個の`EditText`に分解することにしました．  

```activity_main.xml:xml
<?xml version="1.0" encoding="utf-8"?>
 <RelativeLayout
 xmlns:android="http://schemas.android.com/apk/res/android"
 xmlns:app="http://schemas.android.com/apk/res-auto"
 xmlns:tools="http://schemas.android.com/tools"
 android:layout_width="match_parent"
 android:layout_height="match_parent">
 <RelativeLayout
  android:layout_width="wrap_content"
  android:layout_height="wrap_content"
  android:id="@+id/remains"
  android:textAppearance="?android:attr/textAppearanceLarge"
  android:textSize="80sp"
  android:layout_centerInParent="true"
  >
  <EditText
   android:layout_width="100sp"
   android:layout_height="wrap_content"
   android:id="@+id/minute"
   android:text="03"
   android:textSize="80sp"
   android:textAppearance="?android:attr/textAppearanceLarge"
   android:numeric="decimal"
   android:maxLength="2"
   android:digits="1234567890"
   android:inputType="numberDecimal"
   android:autoSizeTextType="none"
   android:justificationMode="none" />
  <TextView
   android:layout_width="wrap_content"
   android:layout_height="wrap_content"
   android:text=":"
   android:textSize="80sp"
   android:id="@+id/separator"
   android:textAppearance="?android:attr/textAppearanceLarge"
   android:layout_alignBaseline="@id/minute"
   android:layout_toRightOf="@id/minute"/>
  <EditText
   android:layout_width="100sp"
   android:layout_height="wrap_content"
   android:id="@+id/second"
   android:text="00"
   android:textSize="80sp"
   android:layout_alignBaseline="@id/separator"
   android:layout_toRightOf="@id/separator"
   android:textAppearance="?android:attr/textAppearanceLarge"
   android:maxLength="2"
   android:digits="1234567890"
   android:numeric="decimal"
   android:inputType="numberDecimal"
   android:autoSizeTextType="none"
   android:justificationMode="none" />
 </RelativeLayout>
 <RelativeLayout
  android:layout_width="wrap_content"
  android:layout_height="wrap_content"
  android:layout_below="@id/remains"
  android:layout_centerHorizontal="true"
  android:id="@+id/buttonGroup">

  <Button
   android:layout_width="wrap_content"
   android:layout_height="wrap_content"
   android:id="@+id/start"
   android:text="start"/>
  <Button
   android:layout_width="wrap_content"
   android:layout_height="wrap_content"
   android:id="@+id/reset"
   android:text="reset"
   android:layout_toRightOf="@id/start"/>
 </RelativeLayout>
</RelativeLayout>
```

少し長めに見えるかもしれないけどあまり大したことはしていません．  
時分を入力するための`TextEdit`は，数値以外の入力を受け付けないようにしたり，文字数を2桁までに制限したりしてプログラムの負担を減らせるようにしていきましょう．  

また，入力状況に応じてUIの大きさが変化されては醜いので，サイズは決め打ちにしてしまいます．

次に，プログラムを見ていきましょう．  

```MainActivity.cs:CS
  // (1)
  private int sec_;
  private int min_ = 3;
  private int cnt_;
  EditText editMin_;
  EditText editSec_;

〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜

   editSec_ = FindViewById<EditText>(Resource.Id.second);
   editMin_ = FindViewById<EditText>(Resource.Id.minute);

   editSec_.TextChanged += (sender, e) => {
    if(!((EditText)sender).IsFocused)
     return;
    if(!((EditText)sender).Text.Equals("")) {
     sec_ = int.Parse(((EditText)sender).Text);
     if(sec_ > 59) {
      sec_ = 59;
      ((EditText)sender).Text = "59";
     } 
    } else {
     sec_ = 0;
    }
   };

   editSec_.FocusChange += (sender, e) => {
    if(((EditText)sender).Text.Equals(""))
     ((EditText)sender).Text = "00";
    if(((EditText)sender).Text.Length == 1)
     ((EditText)sender).Text = "0" + ((EditText)sender).Text;
   };

   editMin_.TextChanged += (sender, e) => {
    if(!((EditText)sender).IsFocused)
     return;
    if(!((EditText)sender).Text.Equals("")) {
     min_ = int.Parse(((EditText)sender).Text);
     if(min_ > 59) {
      min_ = 59;
      ((EditText)sender).Text = "59";
     }
    } else {
     min_ = 0;
    }
   };

   editMin_.FocusChange += (sender, e) => {
    if(((EditText)sender).Text.Equals(""))
     ((EditText)sender).Text = "00";
    if(((EditText)sender).Text.Length == 1)
     ((EditText)sender).Text = "0" + ((EditText)sender).Text;
   };

〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜

  void Action() {
   handler_.RemoveCallbacksAndMessages(null);
   cnt_--;

   if(cnt_ > 0)
    handler_.PostDelayed(Action, 1000);
   else
    Beep();
    
   RunOnUiThread(() => {
    editMin_.Text = (cnt_ / 60).ToString("D2");
    editSec_.Text = (cnt_ % 60).ToString("D2");
   });
  }
```

今回，時間設定を分と秒に分解したのでそれぞれ保持するための変数を用意しておき，そこに設定値を読み込むことにします．**(1)**


何も難しいことはしていませんがここまででだいぶタイマーらしいものが出来上がってきました．

### 一時停止機能
次に，一時停止機能を実装していきたいと思います．
### 最近使用したタイマー
### 時間表示をカッコよくする