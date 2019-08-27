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
最低限キッチンタイマー的な動作をするプログラムを書いてみよう．  
先ほどの要件定義を満たすために，カウントダウン機構とスタート動作，ビープ音の生成・発音機能を実装していく．


```MainActivity.cs:CS
using System;
using Android.App;
using Android.OS;
using Android.Runtime;
using Android.Support.Design.Widget;
using Android.Support.V7.App;
using Android.Views;
using Android.Widget;
using Android.Media;

namespace KitchenTimer {
 [Activity(Label = "@string/app_name", Theme = "@style/AppTheme.NoActionBar", MainLauncher = true)]
 public class MainActivity : AppCompatActivity {

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

   // 時間を表示させるviewの取得
   tv_ = FindViewById<TextView>(Resource.Id.remains);

   // Buttonのクリック動作を設定
   // どうせ保持していても使わないので直接構築
   FindViewById<Button>(Resource.Id.start)
    .Click += (sender, e) => {
     handler_.PostDelayed(() => Action(), 1000);
    };
  }

  protected override void OnResume() {
   base.OnResume();

   // [samples / sec] * [sec] = [samples]
   int samples = (int)(sampleRate_ * duration_); 
   audioBuf_ = new short[samples];

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

  void Action() {
   handler_.RemoveCallbacks(Action);
   sec_--;

   if(sec_ > 0)
    handler_.PostDelayed(Action, 1000);
   else
    Beep();

   // この関数が別スレッドで動いているので，
   // UIスレッドを明示的に指定
   RunOnUiThread(() => {
    tv_.Text = (sec_ / 60).ToString("D2") +
    ":" +
    (sec_ % 60).ToString("D2");
   });

  }

  void Beep() {
   audio_.Stop();
   audio_.ReloadStaticData();
   audio_.Play();
  }
 }
}


```