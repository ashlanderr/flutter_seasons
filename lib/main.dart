import 'dart:convert';

import 'package:flare_flutter/flare.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

var weather;

void main() => rootBundle.loadString("assets/weather.json").then((str) {
  weather = json.decode(str);
  runApp(MaterialApp(home: Home()));
});

class Home extends StatefulWidget {
  @override _State createState() => _State();
}

class _State extends State<Home> with TickerProviderStateMixin {
  DragCtrl _xCtl, _yCtl;
  var _flares = List.generate(4, (_) => FlrCtrl());

  @override
  void initState() {
    super.initState();
    _xCtl = new DragCtrl(this, 3, 0, false, _update);
    _yCtl = new DragCtrl(this, 1, 1, true, _update);
  }

  void _update() => setState(() {
    _flares.forEach((c) => c.time = 1 - _yCtl.value);
  });

  @override
  Widget build(BuildContext context) {
    var media = MediaQuery.of(context);
    var w = media.size.width;
    var h = media.size.height;

    var c = <Widget>[];
    c.addAll(_flare(w));
    c.add(_weather(_xCtl.value, _yCtl.value));

    return Scaffold(
      body: GestureDetector(
        onVerticalDragStart: (d) => _yCtl.start(d.globalPosition.dy),
        onVerticalDragUpdate: (d) => _yCtl.update(d.globalPosition.dy, h),
        onVerticalDragEnd: (d) => _yCtl.end(d.primaryVelocity),
        onHorizontalDragStart: (d) => _xCtl.start(d.globalPosition.dx),
        onHorizontalDragUpdate: (d) => _xCtl.update(d.globalPosition.dx, w),
        onHorizontalDragEnd: (d) => _xCtl.end(d.primaryVelocity),
        child: Stack(children: c)
      )
    );
  }

  List<Widget> _flare(double w) {
    var year = _xCtl.value;
    var files = ["winter", "spring", "summer", "autumn"];

    return List.generate(files.length, (idx) {
      var actor = FlareActor(
        "assets/${files[idx]}.json", fit: BoxFit.cover,
        controller: _flares[idx], shouldClip: false,
      );
      return Positioned(
        left: -year * w * 0.02, width: w * 1.08, top: 0, bottom: 0,
        child: Opacity(
          opacity: 1 - (idx - year).abs().clamp(0.0, 1.0),
          child: Offstage(offstage: year.toInt() == (idx + 2) % 4, child: actor),
        ),
      );
    });
  }
}

int lerp(String k, double season, double day) {
  var st = season.clamp(0.0, 3.0);
  var sf = st % 1;
  var s1 = (st % 4).toInt();
  var s2 = ((st + 1) % 4).toInt();
  var a = weather[s1][0][k] * (1 - sf) + weather[s2][0][k] * sf;
  var b = weather[s1][1][k] * (1 - sf) + weather[s2][1][k] * sf;
  var d = day.clamp(0.0, 1.0);
  return (a * (1 - d) + b * d).round();
}

Widget _weather(double season, double day) {
  var max = lerp('max', season, day);
  var mean = lerp('mean', season, day);
  var min = lerp('min', season, day);
  
  var color = Color.lerp(Color(0xFFE4E4E4), Color(0xFF1F1F1F), (day * 4 - 0.5).clamp(0.0, 1.0));

  var style = TextStyle(fontSize: 54, fontFamily: "Montserrat", fontWeight: FontWeight.w600, color: color);
  var meanText = Text("$mean°c", style: style);
  var deltaText = Text("max $max° / min $min°", style: style.copyWith(fontSize: 18));

  return Positioned(right: 40, top: 165, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[meanText, deltaText]));
}

class FlrCtrl extends FlareController {
  FlutterActorArtboard _artboard;
  ActorAnimation _anim;

  set time(double value) {
    _anim.apply(value * _anim.duration, _artboard, 1);
  }

  @override
  void initialize(FlutterActorArtboard artboard) {
    _artboard = artboard;
    _anim = artboard.animations[0];
    time = 0;
  }

  @override
  bool advance(FlutterActorArtboard artboard, double elapsed) {
    return false;
  }

  @override
  void setViewTransform(viewTransform) {}
}

class DragCtrl {
  var _tmp = 0.0;
  var _slide = 0.0;
  var _state = 0.0;

  TickerProvider ticker;
  double to;
  VoidCallback callback;
  bool middle;
  AnimationController _controller;
  Animation<double> _animation;

  double get value => _animation != null ? _animation.value : _slide;

  DragCtrl(this.ticker, this.to, double init, this.middle, this.callback) {
    _state = _slide = init;
  }

  void start(double pos) {
    _controller?.dispose();
    _controller = null;
    _animation = null;
    _tmp = pos;
    callback();
  }

  void update(double pos, double size) {
    _slide -= (pos - _tmp) / size;
    _slide = _slide.clamp(-0.2, to + 0.2);
    _tmp = pos;
    callback();
  }

  void end(double velocity) {
    double dir = 0;
    double delta = (_state - _slide);

    if (velocity.abs() > 600)
      dir = velocity.sign;
    else if (delta.abs() > 0.3 && !middle)
      dir = delta.sign;
    else if (middle)
      return;

    _state = (_state - dir).clamp(0.0, to);
    _controller = AnimationController(vsync: ticker, duration: Duration(milliseconds: 500))..forward(from: 0);
    _animation = Tween(begin: _slide, end: _state).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = _state;
    _controller.addListener(callback);
  }
}