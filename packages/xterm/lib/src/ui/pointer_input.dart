enum PointerInput { tap, scroll, drag, move }

class PointerInputs {
  final Set<PointerInput> inputs;

  const PointerInputs(this.inputs);

  const PointerInputs.none() : inputs = const <PointerInput>{};

  const PointerInputs.all()
      : inputs = const <PointerInput>{
          PointerInput.tap,
          PointerInput.scroll,
          PointerInput.drag,
          PointerInput.move,
        };
}
