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
     handler_.PostDelayed(() => Action(), 1000);
    };
  }

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
   handler_.RemoveCallbacks(Action);
   sec_--;

   if(sec_ > 0)
    handler_.PostDelayed(Action, 1000);
   else
    Beep();

   // (5)
   // この関数が別スレッドで動いているので，
   // UIスレッドを明示的に指定
   RunOnUiThread(() => {
    tv_.Text = (sec_ / 60).ToString("D2") +
    ":" +
    (sec_ % 60).ToString("D2");
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
**(3)** では，カウント終了時に鳴らす音声を生成しています．  
思いっきり高校物理の波動の分野ですね．覚えてますか？？笑  
**(4)** の`Action`という関数は，ボタンクリック時に1000[ms]遅延で実行するタスク，つまりタイマーカウントを担っています，遅延動作をネストしたかったのでわざわざ関数化しました．  
**(5)** の部分は，タイマーの残り時間をフォアグラウンドで実行するためのコードです．`RunOnUiThread()`を用いる事で，UIの更新をスレッドセーフ(?)に行うことができるのです．  

さて，これだけで本当に簡単なキッチンタイマーができてしまいました．  
しかしながらこれでは，スタートしてカウント終了したらそれっきりです．これでは使い物になりませんよね．  
て事で，こいつに機能をじゃんじゃん追加していって本格的なキッチンタイマーを作っていくこととしましょう．  

## 機能を追加する
### リセット機能
### 任意の時間を指定
### 一時停止機能
### 最近使用したタイマー
### UIをカッコよくする