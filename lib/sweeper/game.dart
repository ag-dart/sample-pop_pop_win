class Game {
  final Field field;
  final Array2d<SquareState> _states;
  final EventHandle<EventArgs> _updatedEvent;

  GameState _state;
  int _minesLeft;
  int _revealsLeft;
  Date _startTime;
  Date _endTime;

  Game(Field field) :
    this.field = field,
    _state = GameState.notStarted,
    _states = new Array2d<SquareState>(field.width, field.height, SquareState.hidden),
    _updatedEvent = new EventHandle<EventArgs>() {
    assert(field != null);
    _minesLeft = field.mineCount;
    _revealsLeft = field.length - field.mineCount;
  }

  int get minesLeft() => _minesLeft;

  int get revealsLeft() => _revealsLeft;

  GameState get state() => _state;

  EventRoot get updated() => _updatedEvent;

  SquareState getSquareState(int x, int y) => _states.get(x,y);

  bool get gameEnded() => _state == GameState.won || _state == GameState.lost;

  Duration get duration() {
    if(_startTime == null) {
      assert(state == GameState.notStarted);
      return null;
    } else {
      assert((state == GameState.started) == (_endTime == null));
      final end = (_endTime == null) ? new Date.now() : _endTime;
      return end.difference(_startTime);
    }
  }

  void setFlag(int x, int y, bool value) {
    _ensureStarted();
    assert(value != null);

    final currentSS = _states.get(x,y);
    if(value) {
      require(currentSS == SquareState.hidden);
      _states.set(x,y,SquareState.flagged);
      _minesLeft--;
    } else {
      require(currentSS == SquareState.flagged);
      _states.set(x,y,SquareState.hidden);
      _minesLeft++;
    }
    _update();
  }

  int reveal(int x, int y) {
    _ensureStarted();
    final currentSS = _states.get(x,y);
    require(currentSS != SquareState.flagged, 'Cannot reveal a flagged square');

    int reveals = 0;

    // normal reveal
    if(currentSS == SquareState.hidden) {
      if(field.get(x, y)) {
        _setLost();
      } else {
        reveals = _doReveal(x, y);
      }
    } else if(currentSS == SquareState.revealed) {
      // might be a 'chord' reveal
      final adjFlags = _getAdjacentFlagCount(x, y);
      final adjCount = field.getAdjacentCount(x, y);
      if(adjFlags == adjCount) {
        reveals = _doChord(x, y);
      }
    }
    _update();
    return reveals;
  }

  int _doChord(int x, int y) {
    // this does not repeat a bunch of validations that have already happened
    // be careful
    final currentSS = _states.get(x,y);
    assert(currentSS == SquareState.revealed);

    final flagged = new List<int>();
    final hidden = new List<int>();
    final adjCount = field.getAdjacentCount(x, y);

    bool failed = false;

    for(final i in field.getAdjacentIndices(x, y)) {
      if(_states[i] == SquareState.hidden) {
        hidden.add(i);
        if(field[i]) {
          failed = true;
        }
      } else if(_states[i] == SquareState.flagged) {
        flagged.add(i);
      }
    }

    // for now we assume counts have been checked
    assert(flagged.length == adjCount);

    int reveals = 0;

    // if any of the hidden are mines, we've failed
    if(failed) {
      // TODO: assert one of the flags must be wrong, right?
      _setLost();
    } else {
      for(final i in hidden) {
        final c = field.getCoordinate(i);
        reveals += reveal(c.Item1, c.Item2);
      }
    }

    return reveals;
  }

  int _doReveal(int x, int y) {
    assert(_states.get(x,y) == SquareState.hidden);
    _states.set(x,y,SquareState.revealed);
    _revealsLeft--;
    assert(_revealsLeft >= 0);
    int revealCount = 1;
    if(_revealsLeft == 0) {
      _setWon();
    } else if (field.getAdjacentCount(x, y) == 0) {
      for(final i in field.getAdjacentIndices(x, y)) {
        if(_states[i] == SquareState.hidden) {
          final c = field.getCoordinate(i);
          revealCount += _doReveal(c.Item1, c.Item2);
          assert(state == GameState.started || state == GameState.won);
        }
      }
    }
    return revealCount;
  }

  void _setWon() {
    assert(state == GameState.started);
    for(int i = 0; i < field.length; i++) {
      if(field[i]) {
        _states[i] = SquareState.safe;
      }
    }
    _setState(GameState.won);
  }

  void _setLost() {
    assert(state == GameState.started);
    for(int i = 0; i < field.length; i++) {
      if(field[i]) {
        _states[i] = SquareState.mine;
      }
    }
    _setState(GameState.lost);
  }

  void _update() => _updatedEvent.fireEvent(EventArgs.empty);

  void _setState(GameState value) {
    assert((_state == GameState.notStarted) == (_startTime == null));
    if(_state != value) {
      _state = value;
      if(_state == GameState.started) {
        _startTime = new Date.now();
      } else if(gameEnded) {
        _endTime = new Date.now();
      }
    }
  }

  void _ensureStarted() {
    if(state == GameState.notStarted) {
      assert(_startTime == null);
      _setState(GameState.started);
    }
    assert(state == GameState.started);
    assert(_startTime != null);
  }

  int _getAdjacentFlagCount(int x, int y) {
    assert(_states.get(x,y) == SquareState.revealed);

    int val = 0;
    for(final i in field.getAdjacentIndices(x, y)) {
      if(_states[i] == SquareState.flagged) {
        val++;
      }
    }
    return val;
  }
}