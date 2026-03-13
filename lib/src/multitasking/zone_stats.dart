import 'dart:async';

class ZoneStats {
  int _activeMicrotasks = 0;

  int _activePeriodicTimers = 0;

  int _activeTimers = 0;

  int _createdPeriodicTimers = 0;

  int _createdTimers = 0;

  int _scheduledMicrotasks = 0;

  late final ZoneSpecification specification;

  ZoneStats() {
    specification = ZoneSpecification(
      createPeriodicTimer: _createPeriodicTimer,
      createTimer: _createTimer,
      scheduleMicrotask: _scheduleMicrotask,
    );
  }

  int get activeMicrotasks => _activeMicrotasks;

  int get activePeriodicTimers => _activePeriodicTimers;

  int get activeTimers => _activeTimers;

  int get createdPeriodicTimers => _createdPeriodicTimers;

  int get createdTimers => _createdTimers;

  /// Returns `true` if there is any activity in the [Zone].\
  /// Any scheduled and uncompleted microtasks or active timers in a [Zone] are
  /// considered activity in that zone.
  bool get isZoneActive =>
      _activeMicrotasks > 0 || _activePeriodicTimers > 0 || _activeTimers > 0;

  int get scheduledMicrotasks => _scheduledMicrotasks;

  Timer _createPeriodicTimer(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Duration period,
    void Function(Timer timer) f,
  ) {
    void onCancel() {
      _activePeriodicTimers--;
    }

    final timer = parent.createPeriodicTimer(zone, period, f);
    _createdPeriodicTimers++;
    _activePeriodicTimers++;
    return _Timer(timer, onCancel);
  }

  Timer _createTimer(
    Zone self,
    ZoneDelegate parent,
    Zone zone,
    Duration period,
    void Function() f,
  ) {
    void callback() {
      try {
        return f();
      } finally {
        _activeTimers--;
      }
    }

    void onCancel() {
      _activeTimers--;
    }

    final timer = parent.createTimer(zone, period, callback);
    _createdTimers++;
    _activeTimers++;
    return _Timer(timer, onCancel);
  }

  void _scheduleMicrotask(
      Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
    void callback() {
      try {
        return f();
      } finally {
        _activeMicrotasks--;
      }
    }

    _scheduledMicrotasks++;
    _activeMicrotasks++;
    return parent.scheduleMicrotask(zone, callback);
  }
}

class _Timer implements Timer {
  final void Function() _onCancel;

  final Timer _timer;

  _Timer(this._timer, this._onCancel);

  @override
  bool get isActive => _timer.isActive;

  @override
  int get tick => _timer.tick;

  @override
  void cancel() {
    if (_timer.isActive) {
      _onCancel();
    }

    _timer.cancel();
  }
}
