## QLlibs++ - Modern C++ libraries
---

### Libraries

- [jmp](#jmp)
- [mem](#mem)
- [mp](#mp)
- [mph](#mph)
- [reflect](#reflect)
- [sml](#sml)
- [swar](#swar)
- [ut](#ut)

---

[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fjmp.svg)](https://github.com/qlibs/jmp/releases)
[![build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/oo3n73Mxv)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/v8W3Pzbxd)

---------------------------------------

## JMP: Static branch library

> https://en.wikipedia.org/wiki/Branch_(computer_science)

### Use cases

> Performance
> - branch is relatively stable through its life cycle `and/or`
> - branch is expensive to compute / require [memory access](https://en.wikipedia.org/wiki/CPU_cache) `and/or`
> - branch is hard to learn by the [branch predictor](https://en.wikipedia.org/wiki/Branch_predictor)

> Examples: logging, tracing, dispatching, fast path, devirtualization, ...

### Features

- Single header (https://raw.githubusercontent.com/qlibs/jmp/main/jmp - for integration see [FAQ](#faq))
- Minimal [API](#api)
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))

### Requirements

- C++20 ([clang++10+, g++10+](https://en.cppreference.com/w/cpp/compiler_support)) / [x86-64](https://en.wikipedia.org/wiki/X86-64) / [Linux](https://en.wikipedia.org/wiki/Linux)

---

### Overview

> `static_branch<bool>` (https://godbolt.org/z/v8W3Pzbxd)

```cpp
/**
 * constexpr minimal overhead static branch changed at run-time via code patching
 */
constexpr jmp::static_branch<bool> static_bool = false;

/**
 * Note: `fn` can be inline/noinline/constexpr/etc.
 */
void fn() {
  if (static_bool) { // Note: [[likely]], [[unlikely]] has no impact
    std::puts("taken");
  } else {
    std::puts("not taken");
  }
}

int main() {
  if (not jmp::init()) { // enables run-time code patching
    return errno;
  }

  fn(); // not taken

  static_bool = true;
  fn(); // taken
}
```

```cpp
main: // $CXX -O3
# init
  xor eax, eax # return 0

# fn(); // not taken
  nop
.Ltmp0:
  mov edi, OFFSET FLAT:.LC0
  jmp puts
  ret
.Ltmp1:
  mov edi, OFFSET FLAT:.LC1
  jmp puts
  ret

# static_bool = true;
  call static_bool.operator=(true)

# fn(); // taken
  jmp .Ltmp1 // code patching (nop->jmp .Ltmp1)
.Ltmp0:
  mov edi, OFFSET FLAT:.LC0
  jmp puts
  ret
.Ltmp1:
  mov edi, OFFSET FLAT:.LC1
  jmp puts
  ret

.LC0: .asciz "not taken"
.LC1: .asciz "taken"
```

---

> `static_branch<bool> vs bool` (https://godbolt.org/z/jvKGdPMWK)

```cpp
constexpr jmp::static_branch<bool> static_bool = false;

void fn() {
  if (static_bool) {
    throw;
  } else {
    std::puts("else");
  }
}

fn():
  // static_bool = false;
  [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
   1      0     0.25                        nop
   1      1     0.33                        lea   rdi, [rip + .L.str]
   1      1     0.50                        jmp   puts
   1      1     1.00           *            .LBB0_1: push rax
   1      1     0.50                        call  __cxa_rethrow@PLT

  // static_bool = true;
  [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
   1      1     0.50                        jmp   .LBB0_1
   1      1     0.50                        lea   rdi, [rip + .L.str]
   1      1     0.50                        jmp   puts
   3      2     1.00           *            .LBB0_1: push rax
   4      3     1.00                        call  __cxa_rethrow@PLT

[1]: #uOps   [2]: Latency  [3]: RThroughput
[4]: MayLoad [5]: MayStore [6]: HasSideEffects (U)
```

```cpp
bool dynamic_bool = false;

void fn() {
  if (dynamic_bool) {
    throw;
  } else {
    std::puts("else");
  }
}

fn():
  // dynamic_bool = false;
  [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
   2      5     0.50    *                   cmp   byte ptr [rip + dynamic_bool], 1
   1      1     0.25                        je    .LBB0_1
   1      1     0.25                        lea   rdi, [rip + .L.str]
   1      1     0.25                        jmp   puts
   1      1     0.50           *            .LBB0_1: push rax
   1      1     0.25                        call  __cxa_rethrow@PLT

  // dynamic_bool = true;
  [1]    [2]    [3]    [4]    [5]    [6]    Instructions:
   2      5     0.50    *                   cmp   byte ptr [rip + dynamic_bool], 1
   1      1     0.25                        je    .LBB0_1
   1      1     0.25                        lea   rdi, [rip + .L.str]
   1      1     0.25                        jmp   puts
   1      1     0.50           *            .LBB0_1: push rax
   1      1     0.25                        call  __cxa_rethrow@PLT

[1]: #uOps   [2]: Latency  [3]: RThroughput
[4]: MayLoad [5]: MayStore [6]: HasSideEffects (U)
```

----

> `static_branch<T, T Min, T Max>` (https://godbolt.org/z/Tz4ox7ncv)

```cpp
constexpr jmp::static_branch<int, 0, 2> static_int = 0; // range: <0, 2>

void fn() {
  switch (static_int) {
    default: std::unreachable();
    case 0: std::puts("0"); return;
    case 1: std::puts("1"); return;
    case 2: std::puts("2"); return;
  }
}

int main() {
  if (not jmp::init()) { // enables run-time code patching
    return errno;
  }

  fn(); // 0

  static_int = 1;
  fn(); // 1

  static_int = 2;
  fn(); // 2
}
```

```cpp
fn: // $CXX -O3 -fno-inline
  nop # code patching (nop->jmp .Ltmp1|.Ltmp2)
.Ltmp0:
  mov edi, OFFSET FLAT:.LC0
  jmp puts
  ret
.Ltmp1:
  mov edi, OFFSET FLAT:.LC1
  jmp puts
  ret
.Ltmp2:
  mov edi, OFFSET FLAT:.LC2
  jmp puts
  ret

main:
  // ... init

  fn() // 0

  call static_int.operator=(1)
  fn() // 1

  call static_int.operator=(2)
  fn() // 2

.LC0: .asciz "0"
.LC1: .asciz "1"
.LC2: .asciz "2"
```

----

### Examples

> `variant` (https://godbolt.org/z/TKPdYPv3P) | (https://wg21.link/P2996)

```cpp
template<class... Ts>
class variant {
  static constexpr jmp::static_branch<std::size_t, 0, sizeof...(Ts)> index_ = 0u;

 public:
   constexpr variant() = default;

   template<class T> requires (not std::is_base_of_v<variant, std::remove_cvref_t<T>>)
   constexpr explicit(false) variant(T&& t) {
    constexpr auto index = [] {
      std::array match{std::is_same_v<Ts, std::remove_cvref_t<T>>...};
      return std::ranges::find(match, true) - match.begin();
    }();
    index_ = index;
    std::construct_at(&storage_.[:
      nonstatic_data_members_of(^storage)[index + 1u]
    :], std::forward<T>(t));
   }
   constexpr ~variant()
    requires (std::is_trivially_destructible_v<Ts> and ...) = default;

   template<class Fn>
   constexpr auto visit(Fn&& fn) const -> decltype(auto) {
    return [&]<auto I = 0u>(this auto&& self) {
      if constexpr (I == sizeof...(Ts)) {
        std::unreachable();
      } else {
        switch (index_) {
          default: return self.template operator()<I + 1u>();
          case I:  return std::invoke(std::forward<Fn>(fn), storage_.[:
                            nonstatic_data_members_of(^storage)[I + 1u]
                          :]);
        }
      }
    }();
  }

private:
  union storage;
  struct empty{ };
  static_assert(is_type(define_class(^storage, {
    std::meta::data_member_spec(^empty, {.name = "empty"}),
    std::meta::data_member_spec(^Ts)...
  })));
  storage storage_{.empty={}};
};
```

```cpp
void usage(const variant<bool, int, float>& v) {
  v.visit(overload{
    [](bool)  { std::puts("bool");  },
    [](int)   { std::puts("int");   },
    [](float) { std::puts("float"); },
  });
}

int main() {
  if (not jmp::init()) { // enables run-time code patching
    return errno;
  }

  variant<bool, int, float> v{};

  v = true;
  usage(v);

  v = 42;
  usage(v);

  v = 42.f;
  usage(v);
}
```

```cpp
usage(variant<bool, int, float> const&):
  nop # code patching (nop->jmp .Ltmp1|.Ltmp2)
.Ltmp0:
  mov edi, OFFSET FLAT:.LC0
  jmp puts
  ret
.Ltmp1:
  mov edi, OFFSET FLAT:.LC1
  jmp puts
  ret
.Ltmp2:
  mov edi, OFFSET FLAT:.LC2
  jmp puts
  ret

.LC0: .asciz  "bool"
.LC1: .asciz  "int"
.LC2: .asciz  "float"
```

---

> Dispatching techniques (https://godbolt.org/z/cfKP9E8W9)

```cpp
auto f1() -> int { return 42; }
auto f2() -> int { return 77; }
auto f3() -> int { return 99; }
```

```cpp
auto if_else(bool b) -> int {                  # if_else(bool):
  if (b) {                                     #   testl   %edi, %edi
    return f1();                               #   movl    $42, %ecx
  } else {                                     #   movl    $77, %eax
    return f2();                               #   cmovnel %ecx, %eax # cmove or cmp
  }                                            #   retq
}                                              #

auto if_else_likely(bool b) -> int {           # if_else_likely(bool):
  if (b) [[likely]] {                          #   movl    $42, %eax # likely
    return f1();                               #   testl   %edi, %edi
  } else {                                     #   je      .LBB3_1
    return f2();                               #   retq
  }                                            # .LBB3_1:
}                                              #   movl    $77, %eax
                                               #   retq

auto ternary_op(bool b) -> int {               # ternary_op(bool):
  return b ? f1() : f2();                      #   testl   %edi, %edi
}                                              #   movl    $42, %ecx
                                               #   movl    $77, %eax
                                               #   cmovnel %ecx, %eax # often cmove
                                               #   retq

auto jump_table(bool b) -> int {               # jump_table(bool):
  static constexpr int (*dispatch[])(){        #  movl    %edi, %eax
    &f1, &f2                                   #  leaq    dispatch(%rip), %rcx
  };                                           #  jmpq    *(%rcx,%rax,8) # or call
  return dispatch[b]();                        #
}                                              # dispatch:
                                               #  .quad   f1()
                                               #  .quad   f2()

auto jump_table_musttail(bool b) -> int {      # jump_table_musttail(bool):
  static constexpr int (*dispatch[])(bool){    #   movl    %edi, %eax
    [](bool) { return f1(); },                 #   leaq    dispatch(%rip), %rcx
    [](bool) { return f2(); },                 #   jmpq    *(%rcx,%rax,8) # always jmp
  };                                           #
  [[clang::musttail]] return dispatch[b](b);   # dispatch:
}                                              #  .quad   f1::__invoke(bool)
                                               #  .quad   f2::__invoke(bool)

auto computed_goto(bool b) -> int {            # computed_goto(bool):
  static constexpr void* labels[]{&&L1, &&L2}; #   movl    %edi, %eax
  goto *labels[b];                             #   leaq    labels(%rip), %rcx
  L1: return f1();                             #   jmpq    *(%rcx,%rax,8)
  L2: return f2();                             # .Ltmp15:
}                                              #   movl    $42, %eax
                                               #   retq
                                               # .Ltmp17:
                                               #   movl    $77, %eax
                                               #   retq
                                               #
                                               # labels:
                                               #   .quad   .Ltmp15
                                               #   .quad   .Ltmp17

jmp::static_branch<bool> branch = false;       # jmp():
auto jmp() -> int {                            #   nop|jmp .Ltmp1 # code patching
  if (branch) {                                # .Ltmp0:
    return f1();                               #   movl    $42, %eax
  } else {                                     #   retq
    return f2();                               # .Ltmp1:
  }                                            #   movl    $77, %eax
}                                              #   retq
```

```cpp
auto if_else(int i) -> int {                   # if_else(int):
  [[assume(i >= 0 and i <= 2)]];               #   cmpl    $1, %edi
  if (i == 0) {                                #   movl    $77, %eax
    return f1();                               #   movl    $99, %ecx
  } else if (i == 1) {                         #   cmovel  %eax, %ecx
    return f2();                               #   testl   %edi, %edi
  } else if (i == 2) {                         #   movl    $42, %eax
    return f3();                               #   cmovnel %ecx, %eax
  } else {                                     #   retq
    std::unreachable();
  }
}

auto switch_case(int i) -> int {               # switch_case(int):
  [[assume(i >= 0 and i <= 2)]];               #   movl    %edi, %eax
  switch (i) {                                 #   leaq    .Lswitch.table(%rip), %rcx
    default: std::unreachable();               #   movl    (%rcx,%rax,4), %eax
    case 0: return f1();                       #   retq
    case 1: return f2();                       # .Lswitch.table(int):
    case 2: return f3();                       #   .long   42
  }                                            #   .long   77
}                                              #   .long   99

auto jump_table(int i) -> int {                # jump_table(int):
  [[assume(i >= 0 and i <= 2)]];               #   movl    %edi, %eax
  static constexpr int (*dispatch[])(int){     #   leaq    dispatch(%rip), %rcx
    [](int) { return f1(); },                  #   jmpq    *(%rcx,%rax,8) # always jmp
    [](int) { return f2(); },                  # dispatch:
    [](int) { return f3(); },                  #  .quad   f1()
  };                                           #  .quad   f2()
  [[clang::musttail]] return dispatch[i](i);   #  .quad   f3()
}

auto computed_goto(int i) -> int {             # computed_goto(int):
  [[assume(i >= 0 and i <= 2)]];               #   movl    %edi, %eax
  static constexpr void* labels[]{             #   leaq    labels(%rip), %rcx
    &&L1, &&L2, &&L3                           #   jmpq    *(%rcx,%rax,8)
  };                                           # .Ltmp35:
  goto *labels[i];                             #   movl    $42, %eax
  L1: return f1();                             #   retq
  L2: return f2();                             # .Ltmp37:
  L3: return f3();                             #   movl    $99, %eax
}                                              #   retq
                                               # .Ltmp39:
                                               #   movl    $77, %eax
                                               #   retq
                                               #
                                               # labels:
                                               #   .quad   .Ltmp35
                                               #   .quad   .Ltmp37
                                               #   .quad   .Ltmp39

jmp::static_branch<int, 0, 2> branch = 0;      # jmp():
auto jmp() -> int {                            #   jmp .LBB21_0|.LBB21_1|.LBB21_2
  switch (branch) {                            # .LBB21_0:
    default: std::unreachable();               #   movl    $42, %eax
    case 0: return f1();                       #   retq
    case 1: return f2();                       # .LBB21_1:
    case 2: return f3();                       #   movl    $99, %eax
  }                                            #   retq
}                                              # .LBB21_2:
                                               #   movl    $77, %eax
                                               #   retq
```
---

> [Fast/Slow path](https://en.wikipedia.org/wiki/Fast_path) (https://godbolt.org/z/qvar9ThK9)

```cpp
[[gnu::always_inline]] inline void fast_path() { std::puts("fast_path"); }
[[gnu::cold]] void slow_path() { std::puts("slow_path"); }

constexpr jmp::static_branch<bool> disarmed = false;

void trigger() {
  if (not disarmed) { // { false: nop, true: jmp }
    fast_path();
  } else {
    slow_path();
  }
}
```

```cpp
trigger(): // $CXX -O3
  nop                              # code patching (nop->jmp .Ltmp1)
 .Ltmp0:                           # fast path (inlined)
  mov edi, OFFSET FLAT:.LC1
  jmp puts
 .Ltmp1:                           # slow path (cold)
  jmp slow_path() # [clone .cold]
```

---

### API

```cpp
/**
 * Minimal overhead (via code patching) static branch
 */
template<class T, T...> struct static_branch;

template<> struct static_branch<bool> final {
  /**
   * static_assert(sizeof(static_branch<bool>) == 1u)
   * @param value initial branch value (false)
   */
  constexpr explicit(false) static_branch(const bool value) noexcept;
  constexpr static_branch(const static_branch&) noexcept = delete;
  constexpr static_branch(static_branch&&) noexcept = delete;
  constexpr static_branch& operator=(const static_branch&) noexcept = delete;
  constexpr static_branch& operator=(static_branch&&) noexcept = delete;

  /**
   * Updates branch value
   * @param value new branch value
   */
  constexpr const auto& operator=(const bool value) const noexcept;

  [[gnu::always_inline]] [[nodiscard]]
  inline explicit(false) operator bool() const noexcept;
};

template<class T, T Min, T Max>
  requires requires(T t) { reinterpret_cast<T>(t); } and
  (Max - Min >= 2 and Max - Min <= 7)
struct static_branch<T, Min, Max> final {
  /**
   * static_assert(sizeof(static_branch<bool>) == 1u)
   * @param value initial branch value (false)
   */
  constexpr explicit(false) static_branch(const T value) noexcept;
  constexpr static_branch(const static_branch&) noexcept = delete;
  constexpr static_branch(static_branch&&) noexcept = delete;
  constexpr static_branch& operator=(const static_branch&) noexcept = delete;
  constexpr static_branch& operator=(static_branch&&) noexcept = delete;

  /**
   * Updates branch value
   * @param value new branch value
   */
  constexpr const auto& operator=(const T value) const noexcept;

  [[gnu::always_inline]] [[nodiscard]]
  inline explicit(false) operator T() const noexcept;
};
```

---

### FAQ

- How does it work?

  > `jmp` is using technique called code patching - which basically means that the code modifies itself.

  `jmp::static_branch` is based on https://docs.kernel.org/staging/static-keys.html and it requires `asm goto` support (gcc, clang).
  `jmp` currently supports x86-64 Linux, but other platforms can be added using the same technique.

  > Walkthrough

    ```cpp
    constexpr jmp::static_branch<bool> b = false;

    if (b) {
      return 42;
    } else {
      return 0;
    }
    ```

  > Will emit...

    ```cpp
    main:
      .byte 15 31 68 0 0 # nop - https://www.felixcloutier.com/x86/nop
    .LBB0:
      xor eax, eax # return 0
      ret
    .LBB1:
      mov eax, 42 # return 42
      ret
    ```

  > Will effectively execute...

    ```cpp
    main:
      nop
      xor eax, eax # return 0
      ret
    ```

  > If the branch value will be changed (at run-time)...

    ```cpp
    b = true;

    if (b) {
      return 42;
    } else {
      return 0;
    }
    ```

  > Will emit...

    ```cpp
    main:
      call b.operator=(true); # nop->jmp or jmp->nop

      jmp .LBB1: (nop->jmp - changed in the memory of the program)
    .LBB0:
      xor eax, eax # return 0
      ret
    .LBB1:
      mov eax, 42 # return 42
      ret
    ```

- What platforms are supported?

  > Only x86_64 is currently supported but the technique is compatible with other platforms as proven by https://docs.kernel.org/staging/static-keys.html.

- What is the cost of switching the branch?

  > Cost = number of inlined versions * memcpy (`5 bytes` for `static_branch<bool>` or `4 bytes` for `static_branch<T>`).
    In case of `[[gnu::noinline]]` the cost is a single memcpy otherwise it will be a loop over all inlined versions.

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name jmp
      GITHUB_REPOSITORY qlibs/jmp
      GIT_TAG v5.0.0
    )
    add_library(mp INTERFACE)
    target_include_directories(mp SYSTEM INTERFACE ${mp_SOURCE_DIR})
    add_library(jmp::jmp ALIAS jmp)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} jmp::jmp)
    ```

- Acknowledgments

  > - https://docs.kernel.org/staging/static-keys.html
  > - https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
  > - https://www.agner.org/optimize/instruction_tables.pdf
  > - https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html
  > - https://www.felixcloutier.com/documents/gcc-asm.html
  > - https://www.felixcloutier.com/x86
  > - https://uops.info/table.html
  > - https://arxiv.org/abs/2308.14185
  > - https://arxiv.org/abs/2011.13127
---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fmem.svg)](https://github.com/qlibs/mem/releases)
[![build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/ensvKohTs)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/cqch69rGh)

---------------------------------------

## mem: Memory Allocators

> [https://en.wikipedia.org/wiki/Allocator_C++](https://en.wikipedia.org/wiki/Allocator_(C%2B%2B))

### Features

- Single header (https://raw.githubusercontent.com/qlibs/mem/main/mem - for integration see [FAQ](#faq))
- Minimal [API](#api)
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))

### Requirements

- C++20 ([clang++12+, g++11+](https://en.cppreference.com/w/cpp/compiler_support)) / [Linux](https://en.wikipedia.org/wiki/Linux)

---

### Overview

```cpp
static_assert(mem::allocator<std::allocator<int>>);
static_assert(mem::allocator<mem::stack_allocator<int, 1024u>>);
static_assert(mem::allocator<mem::huge_page_allocator<int>>);
static_assert(mem::allocator<mem::numa_allocator<int>>);
```

```cpp
std::vector<int, mem::stack_allocator<int, 1024u>> v{};
```

```cpp
// echo 20 > /proc/sys/vm/nr_hugepages
std::vector<int, mem::huge_page_allocator<int>> v{};
```

```cpp
// -lnuma (requires libnuma-dev)
std::vector<int, mem::numa_allocator<int>> v{};
```

---

### API

```cpp
template<class TAllocator>
concept allocator = requires(TAllocator alloc,
                             typename TAllocator::value_type* ptr,
                             std::size_t n) {
  typename TAllocator::value_type;
  { alloc.allocate(n) } -> std::same_as<decltype(ptr)>;
  { alloc.deallocate(ptr, n) } -> std::same_as<void>;
  #if __cpp_lib_allocate_at_least >= 202302L
  { allocate_at_least(n) } -> std::same_as<std::allocation_result<T*, std::size_t>>;
  #endif
};

template<class T,
         std::size_t N,
         std::size_t alignment = alignof(T),
         auto on_error = [] { return nullptr; }>
  requires (alignment <= alignof(std::max_align_t)) and (not (N % alignment))
struct stack_allocator {
  using value_type = T;

  constexpr stack_allocator() noexcept = default;

  [[nodiscard]] constexpr auto allocate(std::size_t n) noexcept(noexcept(on_error())) -> T*;

  #if __cpp_lib_allocate_at_least >= 202302L
  constexpr std::allocation_result<T*, std::size_t>
  allocate_at_least(std::size_t n) noexcept(noexcept(allocate(n));
  #endif

  constexpr void deallocate(T* ptr, std::size_t n) noexcept;
};

template <class T,
          std::size_t N = (1u << 21u),
          auto on_error = [] { return nullptr; }>
struct huge_page_allocator {
  using value_type = T;

  constexpr huge_page_allocator() noexcept = default;

  [[nodiscard]] constexpr auto allocate(std::size_t n) noexcept(noexcept(on_error())) -> T*;

  #if __cpp_lib_allocate_at_least >= 202302L
  constexpr std::allocation_result<T*, std::size_t>
  allocate_at_least(std::size_t n) noexcept(noexcept(allocate(n));
  #endif

  constexpr void deallocate(T *ptr, std::size_t n) noexcept;
};

template<class T, auto on_error = [] { return nullptr; }>
struct numa_allocator {
  using value_type = T;

  constexpr numa_allocator(node_type node = {}) noexcept;

  [[nodiscard]] constexpr auto allocate(std::size_t n) noexcept(noexcept(on_error())) -> T*;

  #if __cpp_lib_allocate_at_least >= 202302L
  constexpr std::allocation_result<T*, std::size_t>
  allocate_at_least(std::size_t n) noexcept(noexcept(allocate(n));
  #endif

  constexpr void deallocate(T* ptr, std::size_t n) noexcept;
};
```

---

### FAQ

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name mem
      GITHUB_REPOSITORY qlibs/mem
      GIT_TAG v1.0.0
    )
    add_library(mp INTERFACE)
    target_include_directories(mp SYSTEM INTERFACE ${mp_SOURCE_DIR})
    add_library(mem::mem ALIAS mem)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} mem::mem)
    ```

- Acknowledgments

  > - https://eel.is/c++draft/allocator.requirements
  > - https://en.cppreference.com/w/cpp/memory/allocator

  > - https://www.kernel.org/doc/html/latest/admin-guide/mm/hugetlbpage.html
  > - https://www.man7.org/linux/man-pages/man2/mmap.2.html
  > - https://www.intel.com/content/www/us/en/docs/programmable/683840/1-2-1/enabling-hugepages.html
  > - https://github.com/libhugetlbfs/libhugetlbfs
  > - https://wiki.debian.org/Hugepages

  > - https://en.wikipedia.org/wiki/Non-uniform_memory_access
  > - https://man7.org/linux/man-pages/man3/numa.3.html
  > - https://www.intel.com/content/www/us/en/developer/articles/technical/use-intel-quickassist-technology-efficiently-with-numa-awareness.html

---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fmp.svg)](https://github.com/qlibs/mp/releases)
[![Build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/dvqhYYGvc)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/3TqPx5WEG)

---------------------------------------

## MP: ~~Template~~ Meta-Programming library

> https://en.wikipedia.org/wiki/Metaprogramming

### Features

- Single header (https://raw.githubusercontent.com/qlibs/mp/main/mp - for integration see [FAQ](#faq))
- Minimal [API](#api) and learning curve (supports STL, ranges, ...)
- Supports debugging (meta-functions can be executed and debugged at run-time - see [examples](#examples))
- Supports reflection (requires https://github.com/qlibs/reflect - see [examples](#examples))
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))
- Optimized compilation-times (see [benchmarks](https://qlibs.github.io/mp))

### Requirements

- C++20 ([clang++13+, g++11+, msvc-19.34+](https://en.cppreference.com/w/cpp/compiler_support))

---

### Overview

> API (https://godbolt.org/z/zTdYGvKKW)

```cpp
// mp::meta
static_assert(mp::meta<int> == mp::meta<int>);
static_assert(mp::meta<int> != mp::meta<void>);
static_assert(typeid(mp::meta<int>) == typeid(mp::meta<void>));

// mp::type_of
constexpr mp::info meta = mp::meta<int>;
mp::type_of<meta> i{}; // same as int i{};
mp::type_of<mp::meta<bool>> b = true; // same as bool b = true;

// mp::apply
template<class...> struct type_list{ };
static_assert(typeid(type_list<int>) == typeid(mp::apply_t<type_list, std::array{meta}>>);

// mp::invoke
static_assert(not mp::invoke<std::is_const>(meta));
static_assert(std::is_same_v<const int, mp::type_of<mp::invoke<std::add_const>(meta)>>);

int main() {
  // mp::for_each
  constexpr auto v = mp::vector{meta};
  mp::for_each<v>([&]<mp::info meta>{ /* ... */ });
}

// and more (see API)...
```

---

### Examples

> Hello World (https://godbolt.org/z/69jGzqPs1)

```cpp
template<size_t N, class... Ts>
using at_c = mp::type_of<std::array{mp::meta<Ts>...}[N]>;

static_assert(std::is_same_v<int, at_c<0, int, bool, float>>);
static_assert(std::is_same_v<bool, at_c<1, int, bool, float>>);
static_assert(std::is_same_v<float, at_c<2, int, bool, float>>);
```

---

> Algorithms (https://godbolt.org/z/GvzjvdPq8)

```cpp
template<class... Ts>
struct example {
  mp::apply_t<std::variant,
      std::array{mp::meta<Ts>...}
    | std::views::drop(1)
    | std::views::reverse
    | std::views::filter([](auto m) { return mp::invoke<std::is_integral>(m); })
    | std::views::transform([](auto m) { return mp::invoke<std::add_const>(m); })
    | std::views::take(2)
    | std::ranges::to<mp::vector<mp::info>>()
  > v;
};

static_assert(
  typeid(std::variant<const int, const short>)
  ==
  typeid(example<double, void, const short, int>::v)
);
```

---

> Reflection - https://github.com/qlibs/reflect (https://godbolt.org/z/qb37G79Ya)

```cpp
struct foo {
  int a;
  bool b;
  float c;
};

constexpr foo f{.a = 42, .b = true, .c = 3.2f};

constexpr mp::vector<mp::info> v =
    members(f)
  | std::views::filter([&](auto meta) { return member_name(meta, f) != "b"; })
  ;

static_assert(std::tuple{42, 3.2f} == to<std::tuple, v>(f));
```

---

> Run-time testing/debugging (https://godbolt.org/z/vTfGGToa4)

```cpp
constexpr auto reverse(std::ranges::range auto v) {
  std::reverse(v.begin(), v.end());
  return v;
}

int main() {
  static_assert(
    std::array{mp::meta<float>, mp::meta<double>, mp::meta<int>}
    ==
    reverse(std::array{mp::meta<int>, mp::meta<double>, mp::meta<float>})
  );

  assert((
    std::array{mp::meta<float>, mp::meta<double>, mp::meta<int>}
    ==
    reverse(std::array{mp::meta<int>, mp::meta<double>, mp::meta<float>})
  ));
}
```

---

### API

```cpp
/**
 * Meta info type
 */
enum class info : size_t { };
```

```cpp
/**
 * Creates meta type
 *
 * @code
 * static_assert(meta<void> == meta<void>);
 * static_assert(meta<void> != meta<int>);
 * @endcode
 */
template<class T> inline constexpr info meta = /* unspecified */;
```

```cpp
/**
 * Returns underlying type from meta type
 *
 * @code
 * static_assert(typeid(type_of<meta<void>>) == typeid(void));
 * @endcode
 */
template<info meta> using type_of = /* unspecified */;
```

```cpp
/**
 * Applies invocable `[] { return vector<info>{...}; }` to
 *                   `T<type_of<info>...>`
 *
 * @code
 * static_assert(typeid(variant<int>) ==
 *               typeid(apply<variant>([] { return vector{meta<int>}; })));
 * @endcode
 */
template<template<class...> class T>
[[nodiscard]] constexpr auto apply(concepts::invocable auto expr);
```

```cpp
/**
 * Applies range to `T<type_of<info>...>`
 *
 * @code
 * static_assert(typeid(variant<int>) ==
 *               typeid(apply<variant, vector{meta<int>}>));
 * @endcode
 */
template<template<class...> class T, concepts::range auto range>
inline constexpr auto apply_v = decltype(apply<T, [] { return range; }>);
```

```cpp
/**
 * Applies range to `T<type_of<info>...>`
 *
 * @code
 * static_assert(typeid(variant<int>) ==
 *               typeid(apply_t<variant, [] { return vector{meta<int>}; }>));
 * @endcode
 */
template<template<class...> class T, concepts::range auto range>
using apply_t = decltype(apply_v<T, range>);
```

```cpp
/**
 * Invokes function with compile-time info based on run-time info
 *
 * @code
 * info i = meta<conts int>; // run-time
 * static_assert(invoke([]<info m> { return std::is_const_v<type_of<m>>; }, i));
 * @endcode
 */
constexpr auto invoke(auto fn, info meta);
```

```cpp
/**
 * Iterates over all elements of a range
 *
 * @code
 * constexpr vector v{meta<int>};
 * for_each<v>([]<info m> {
 *   static_assert(typeid(int) == typeid(type_of<m>));
 * });
 * @endcode
 */
template<concepts::range auto range>
constexpr auto for_each(auto fn);
```

---

### FAQ

- What does it mean that `mp` tests itself upon include?

    > `mp` runs all tests (via static_asserts) upon include. If the include compiled it means all tests are passing and the library works correctly on given compiler, enviornment.

- How to disable running tests at compile-time?

    > When `-DNTEST` is defined static_asserts tests wont be executed upon include.
    Note: Use with caution as disabling tests means that there are no gurantees upon include that given compiler/env combination works as expected.

- How `mp` compares to Reflection for C++26 (https://wg21.link/P2996)?

    > `mp` meta-programming model is very simpilar to P2996 and its based on type erased info object and meta-functions. `mp` also supports all C++ standard library and since verion 2.0.0+ `mp` type names have been adopted to closer reflect the reflection proposal.

    | mp (C++20) | P2996 (C++26*) |
    | - | - |
    | `meta<T>` | `^T` |
    | `type_of<T>` | `typename [: T :]` |
    | `for_each` | `template for` (https://wg21.link/p1306) |
    | `apply` | `substitute` |
    | `invoke<trait>` | `test_trait` |
    | `invoke(fn, m)` | `value_of<R>(reflect_invoke(^fn, {substitute(^meta, {reflect_value(m)})}))` |

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name mp
      GITHUB_REPOSITORY qlibs/mp
      GIT_TAG v2.0.4
    )
    add_library(mp INTERFACE)
    target_include_directories(mp SYSTEM INTERFACE ${mp_SOURCE_DIR})
    add_library(mp::mp ALIAS mp)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} mp::mp);
    ```

- Similar projects?
    > [boost.mp11](https://github.com/boostorg/mp11), [boost.hana](https://github.com/boostorg/hana), [boost.mpl](https://github.com/boostorg/mpl)
---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fmph.svg)](https://github.com/qlibs/mph/releases)
[![build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/cnPv5TxhY)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/jcPPsbEvK)

---------------------------------------

## MPH: [Minimal] Static perfect hash library

> https://en.wikipedia.org/wiki/Perfect_hash_function

### Use case

> A static perfect hash function maps a set of keys known in advance to a set of values with no collisions.

### Features

- Single header (https://raw.githubusercontent.com/qlibs/mph/main/mph - for integration see [FAQ](#faq))
- Self verification upon include (can be disabled by `-DNTEST` - see [FAQ](#faq))
- Compiles cleanly with ([`-Wall -Wextra -Werror -pedantic -pedantic-errors -fno-exceptions -fno-rtti`](https://godbolt.org/z/WraE4q1dE))
- Minimal [API](#api)
- Optimized run-time execution (see [performance](#performance) / [benchmarks](#benchmarks))
- Fast compilation times (see [compilation](#compilation))
- Trade-offs (see [FAQ](#faq))

### Requirements

- C++20 ([gcc-12+, clang-15+](https://godbolt.org/z/WraE4q1dE)) / [optional] ([bmi2](https://en.wikipedia.org/wiki/X86_Bit_manipulation_instruction_set)), [optional] ([simd](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data)),

### Hello world (https://godbolt.org/z/dzd6o3Pxo)

```cpp
enum class color { red, green, blue };

constexpr auto colors = std::array{
  std::pair{"red"sv, color::red},
  std::pair{"green"sv, color::green},
  std::pair{"blue"sv, color::blue},
};

static_assert(color::green == mph::lookup<colors>("green"));
static_assert(color::red   == mph::lookup<colors>("red"));
static_assert(color::blue  == mph::lookup<colors>("blue"));

std::print("{}", mph::lookup<colors>("green"sv)); // prints 1
```

> `mph::lookup` assumes only valid input and returns mapped value direclty.

```cpp
static_assert(not mph::find<colors>("unknown"));
static_assert(mph::find<colors>("green"));
static_assert(mph::find<colors>("red"));
static_assert(mph::find<colors>("blue"));

std::print("{}", *mph::find<colors>("green"sv)); // prints 1
```

> `mph::find` doesnt assume valid input and returns optional of mapped value.

---

<a name="performance"></a>
### Performance (https://godbolt.org/z/rqYj9a1cr)

```cpp
int lookup(int id) {
  static constexpr std::array ids{
    std::pair{54u, 91u},
    std::pair{64u, 324u},
    std::pair{91u, 234u},
  };
  return mph::lookup<ids>(id);
}
```

```cpp
lookup: // g++ -DNDEBUG -std=c++20 -O3
  imull   $1275516394, %edi, %eax
  shrl    $23, %eax
  movl    $24029728, %ecx
  shrxl   %eax, %ecx, %eax
  andl    $511, %eax
  retq
```

### Performance (https://godbolt.org/z/vv6W4nGfb)

```cpp
int lookup(int id) {
  static constexpr std::array ids{
    std::pair{54u, 91u},
    std::pair{324u, 54u},
    std::pair{64u, 324u},
    std::pair{234u, 64u},
    std::pair{91u, 234u},
  };
  return mph::lookup<ids>(id);
}
```

```cpp
lookup: // g++ -DNDEBUG -std=c++20 -O3
  andl    $7, %edi
  leaq    lookup(%rip), %rax
  movl    (%rax,%rdi,4), %eax
  retq

lookup:
 .long   324
 .long   0
 .long   64
 .long   234
 .long   54
 .long   0
 .long   91
```

### Performance (https://godbolt.org/z/qMzxKK4sd)

```cpp
int find(int id) {
  static constexpr std::array ids{
    std::pair{27629, 1},
    std::pair{6280, 2},
    // 1..128 pairs...
    std::pair{33691, 128},
  };
  return *mph::find<ids>(id);
}
```

```cpp
find: // g++ -DNDEBUG -std=c++20 -O3 -mbmi2 -mavx512f
  vpbroadcastd    %edi, %zmm0
  shll            $4, %edi
  movzbl          %dil, %ecx
  leaq            find
  vpcmpeqd        (%rdx,%rcx,4), %zmm0, %k0
  kmovw           %k0, %esi
  kortestw        %k0, %k0
  rep             bsfq %rax, %rax
  movl            $64, %eax
  addl            %eax, %ecx
  xorl            %eax, %eax
  testw           %si, %si
  cmovnel         1024(%rdx,%rcx,4), %eax
  vzeroupper
  retq

find:
  ... // see godbolt
```

---

### Performance (https://godbolt.org/z/KaKzf7Pax)

```cpp
int find(std::span<const char, 8> str) {
  static constexpr auto symbols = std::array{
    std::pair{"AMZN    "sv, 1},
    std::pair{"AAPL    "sv, 2},
    std::pair{"GOOGL   "sv, 3},
    std::pair{"META    "sv, 4},
    std::pair{"MSFT    "sv, 5},
    std::pair{"NVDA    "sv, 6},
    std::pair{"TSLA    "sv, 7},
  };
  return *mph::find<symbols>(str);
}
```

```cpp
find: // g++ -DNDEBUG -std=c++20 -O3 -mbmi2
  movq    8(%rsi), %rax
  movl    $1031, %ecx
  leaq    find(%rip), %rdx
  xorl    %esi, %esi
  movq    (%rax), %rax
  pextq   %rcx, %rax, %rcx
  shll    $4, %ecx
  cmpq    (%rcx,%rdx), %rax
  movzbl  8(%rcx,%rdx), %eax
  cmovnel %esi, %eax
  retq

find:
  ... // see godbolt
```

### Performance (https://godbolt.org/z/fdMPsYWjE)

```cpp
int find(std::string_view str) {
  using std::literals::operator""sv;
  // values assigned from 0..N-1
  static constexpr std::array symbols{
    "BTC "sv, "ETH "sv, "BNB "sv,
    "SOL "sv, "XRP "sv, "DOGE"sv,
    "TON "sv, "ADA "sv, "SHIB"sv,
    "AVAX"sv, "LINK"sv, "BCH "sv,
  };
  return *mph::find<symbols>(str);
}
```

```cpp
find: // g++ -DNDEBUG -std=c++20 -O3 -mbmi2
  shll    $3, %edi
  bzhil   %edi, (%rsi), %eax
  movl    $789, %ecx
  pextl   %ecx, %eax, %ecx
  leaq    find(%rip), %rdx
  xorl    %esi, %esi
  cmpl    (%rdx,%rcx,8), %eax
  movzbl  4(%rdx,%rcx,8), %eax
  cmovnel %esi, %eax
  retq

find:
  ... // see godbolt
```

---

### Examples

- [feature] `lookup/find` customization point - https://godbolt.org/z/enqeGxKK9
- [feature] `to` customization point - https://godbolt.org/z/jTMx4n6j3
- [example] `branchless dispatcher` - https://godbolt.org/z/5PTE3ercE
- [performance - https://wg21.link/P2996] `enum_to_string` - https://godbolt.org/z/ojohP6j7f
- [performance - https://wg21.link/P2996] `string_to_enum` - https://godbolt.org/z/83vGhY7M8

---

<a name="benchmarks"></a>
### Benchmarks (https://github.com/qlibs/mph/tree/benchmark)

> `clang++ -std=c++20 -O3 -DNDEBUG -mbmi2 benchmark.cpp`

```
| ns/op |           op/s | err% |total | benchmark
|------:|---------------:|-----:|-----:|:----------
| 12.25 |  81,602,449.70 | 0.3% | 0.15 | `random_strings_5_len_4.std.map`
|  5.56 | 179,750,906.50 | 0.2% | 0.07 | `random_strings_5_len_4.std.unordered_map`
|  9.17 | 109,096,850.98 | 0.2% | 0.11 | `random_strings_5_len_4.boost.unordered_map`
| 13.48 |  74,210,250.54 | 0.3% | 0.16 | `random_strings_5_len_4.boost.flat_map`
|  7.70 | 129,942,965.18 | 0.3% | 0.09 | `random_strings_5_len_4.gperf`
|  1.61 | 621,532,188.81 | 0.1% | 0.02 | `random_strings_5_len_4.mph`
| 14.66 |  68,218,086.71 | 0.8% | 0.18 | `random_strings_5_len_8.std.map`
| 13.45 |  74,365,239.56 | 0.2% | 0.16 | `random_strings_5_len_8.std.unordered_map`
|  9.68 | 103,355,605.09 | 0.2% | 0.12 | `random_strings_5_len_8.boost.unordered_map`
| 16.00 |  62,517,180.19 | 0.4% | 0.19 | `random_strings_5_len_8.boost.flat_map`
|  7.70 | 129,809,356.36 | 0.3% | 0.09 | `random_strings_5_len_8.gperf`
|  1.58 | 633,084,194.24 | 0.1% | 0.02 | `random_strings_5_len_8.mph`
| 17.21 |  58,109,576.87 | 0.3% | 0.21 | `random_strings_6_len_2_5.std.map`
| 15.28 |  65,461,167.99 | 0.2% | 0.18 | `random_strings_6_len_2_5.std.unordered_map`
| 12.21 |  81,931,391.20 | 0.4% | 0.15 | `random_strings_6_len_2_5.boost.unordered_map`
| 17.15 |  58,323,741.08 | 0.5% | 0.21 | `random_strings_6_len_2_5.boost.flat_map`
|  7.94 | 125,883,197.55 | 0.5% | 0.09 | `random_strings_6_len_2_5.gperf`
|  6.05 | 165,239,616.00 | 0.5% | 0.07 | `random_strings_6_len_2_5.mph`
| 31.61 |  31,631,402.94 | 0.2% | 0.38 | `random_strings_100_len_8.std.map`
| 15.32 |  65,280,594.09 | 0.2% | 0.18 | `random_strings_100_len_8.std.unordered_map`
| 17.13 |  58,383,850.20 | 0.3% | 0.20 | `random_strings_100_len_8.boost.unordered_map`
| 31.42 |  31,822,519.67 | 0.2% | 0.38 | `random_strings_100_len_8.boost.flat_map`
|  8.04 | 124,397,773.85 | 0.2% | 0.10 | `random_strings_100_len_8.gperf`
|  1.58 | 632,813,481.73 | 0.1% | 0.02 | `random_strings_100_len_8.mph`
| 32.62 |  30,656,015.03 | 0.3% | 0.39 | `random_strings_100_len_1_8.std.map`
| 19.34 |  51,697,107.73 | 0.5% | 0.23 | `random_strings_100_len_1_8.std.unordered_map`
| 19.51 |  51,254,525.17 | 0.3% | 0.23 | `random_strings_100_len_1_8.boost.unordered_map`
| 33.58 |  29,780,574.17 | 0.6% | 0.40 | `random_strings_100_len_1_8.boost.flat_map`
| 13.06 |  76,577,037.07 | 0.7% | 0.16 | `random_strings_100_len_1_8.gperf`
|  6.02 | 166,100,665.07 | 0.2% | 0.07 | `random_strings_100_len_1_8.mph`
|  1.28 | 778,723,795.75 | 0.1% | 0.02 | `random_uints_5.mph`
```

> `g++ -std=c++20 -O3 -DNDEBUG -mbmi2 benchmark.cpp`

```cpp
| ns/op |           op/s | err% |total | benchmark
|------:|---------------:|-----:|-----:|:----------
| 12.28 |  81,460,330.38 | 0.9% | 0.15 | `random_strings_5_len_4.std.map`
|  5.29 | 188,967,241.90 | 0.3% | 0.06 | `random_strings_5_len_4.std.unordered_map`
|  9.69 | 103,163,192.67 | 0.2% | 0.12 | `random_strings_5_len_4.boost.unordered_map`
| 13.56 |  73,756,333.08 | 0.4% | 0.16 | `random_strings_5_len_4.boost.flat_map`
|  7.69 | 130,055,662.66 | 0.6% | 0.09 | `random_strings_5_len_4.gperf`
|  1.39 | 718,910,252.82 | 0.1% | 0.02 | `random_strings_5_len_4.mph`
| 14.26 |  70,103,007.82 | 2.4% | 0.17 | `random_strings_5_len_8.std.map`
| 13.36 |  74,871,047.51 | 0.4% | 0.16 | `random_strings_5_len_8.std.unordered_map`
|  9.82 | 101,802,074.00 | 0.3% | 0.12 | `random_strings_5_len_8.boost.unordered_map`
| 15.97 |  62,621,571.95 | 0.3% | 0.19 | `random_strings_5_len_8.boost.flat_map`
|  7.92 | 126,265,206.30 | 0.3% | 0.09 | `random_strings_5_len_8.gperf`
|  1.40 | 713,596,376.62 | 0.4% | 0.02 | `random_strings_5_len_8.mph`
| 15.98 |  62,576,142.34 | 0.5% | 0.19 | `random_strings_6_len_2_5.std.map`
| 17.56 |  56,957,868.12 | 0.5% | 0.21 | `random_strings_6_len_2_5.std.unordered_map`
| 11.68 |  85,637,378.45 | 0.3% | 0.14 | `random_strings_6_len_2_5.boost.unordered_map`
| 17.25 |  57,965,732.68 | 0.6% | 0.21 | `random_strings_6_len_2_5.boost.flat_map`
|  9.13 | 109,580,632.48 | 0.7% | 0.11 | `random_strings_6_len_2_5.gperf`
|  7.17 | 139,563,745.72 | 0.4% | 0.09 | `random_strings_6_len_2_5.mph`
| 30.20 |  33,117,522.76 | 0.7% | 0.36 | `random_strings_100_len_8.std.map`
| 15.01 |  66,627,962.89 | 0.4% | 0.18 | `random_strings_100_len_8.std.unordered_map`
| 16.79 |  59,559,414.60 | 0.6% | 0.20 | `random_strings_100_len_8.boost.unordered_map`
| 31.36 |  31,884,629.57 | 0.8% | 0.38 | `random_strings_100_len_8.boost.flat_map`
|  7.75 | 128,973,947.61 | 0.7% | 0.09 | `random_strings_100_len_8.gperf`
|  1.50 | 667,041,673.54 | 0.1% | 0.02 | `random_strings_100_len_8.mph`
| 30.92 |  32,340,612.08 | 0.4% | 0.37 | `random_strings_100_len_1_8.std.map`
| 25.35 |  39,450,222.09 | 0.4% | 0.30 | `random_strings_100_len_1_8.std.unordered_map`
| 19.76 |  50,609,820.90 | 0.2% | 0.24 | `random_strings_100_len_1_8.boost.unordered_map`
| 32.39 |  30,878,018.77 | 0.6% | 0.39 | `random_strings_100_len_1_8.boost.flat_map`
| 11.20 |  89,270,687.92 | 0.2% | 0.13 | `random_strings_100_len_1_8.gperf`
|  7.17 | 139,471,159.67 | 0.5% | 0.09 | `random_strings_100_len_1_8.mph`
|  1.93 | 519,047,110.39 | 0.3% | 0.02 | `random_uints_5.mph`
```

<a name="compilation"></a>
### Benchmarks (https://qlibs.github.io/mph/perfect_hashing)

[![Benchmark](https://raw.githubusercontent.com/qlibs/mph/benchmark/perfect_hashing/benchmark_int_to_int.png)](https://qlibs.github.io/mph/perfect_hashing)
[![Benchmark](https://raw.githubusercontent.com/qlibs/mph/benchmark/perfect_hashing/benchmark_str_to_int.png)](https://qlibs.github.io/mph/perfect_hashing)

---

### API

```cpp
namespace mph {
/**
 * Static [minimal] perfect hash lookup function
 * @tparam entries constexpr array of keys or key/value pairs
 */
template<const auto& entries>
inline constexpr auto lookup = [](const auto& key) {
  if constexpr(constexpr lookup$magic_lut<entries> lookup{}; lookup) {
    return lookup(key);
  } else {
    return lookup$pext<entries>(key);
  }
};

/**
 * Static perfect hash find function
 * @tparam entries constexpr array of keys or key/value pairs
 */
template<const auto& entries>
inline constexpr auto find =
  []<u8 probability = 50u>(const auto& key, const auto& unknown = {}) -> optional {
    if constexpr (entries.size() == 0u) {
      return unknown;
    } else if constexpr (entries.size() <= 64u) {
      return find$pext<entries>.operator()<probability>(key, unknown);
    } else {
      constexpr auto bucket_size = simd_size_v<key_type, simd_abi::native<key_type>>;
      return find$simd<entries, bucket_size>.operator()<probability>(key, unknown);
    }
  };
} // namespace mph
```

---

### FAQ

- Trade-offs?

    > `mph` supports different types of key/value pairs and thousands of key/value pairs, but not millions - (see [benchmarks](#benchmarks)).

  - All keys have to fit into `uint128_t`, that includes strings.
  - If the above criteria are not satisfied `mph` will [SFINAE](https://en.wikipedia.org/wiki/Substitution_failure_is_not_an_error) away `lookup` function.
  - In such case different backup policy should be used instead (which can be also used as customization point for user-defined `lookup` implementation), for example:

    ```cpp
    template<const auto& entries> requires (entries.size() > 1'000'000)
    inline constexpr auto mph::find =
        [](const auto& key, const auto& unknown = {}) -> optional { ... }
    ```

- How `mph` is working under the hood?

    > `mph` takes advantage of knowing the key/value pairs at compile-time as well as the specific hardware instructions.
      The following is a pseudo code of the `lookup` algorithm for minimal perfect hash table.

    ```python
    def lookup$magic_lut[entries: array](key : any, max_attempts = 100'000):
      # 0. magic and lut for entries [compile-time]
      nbits = sizeof(u32) * CHAR_BIT - countl_zero(max(entries.second))
      mask = (1u << nbits) - 1u;
      shift = sizeof(u32) * CHAR_BIT - nbits;
      lut = {};
      while max_attempts--:
        magic = rand()
        for k, v in entries:
          lut |= v << (k * magic >> shift);

        for k, v in entries:
          if (lut >> (k * magic >> shift) & mask) != v:
            lut = {}
            break

      assert magic != 0 and lut != 0 and shift != 0 and mask != 0

      # 1. lookup [run-time]
      return (lut >> ((key * magic) >> shift)) & mask;
    ```

    > The following is a pseudo code of the `find` algorithm for perfect hash table.

    ```python
    # word: 00101011
    # mask: 11100001
    #    &: 000____1
    # pext: ____0001 # intel/intrinsics-guide/index.html#text=pext
    def pext(a : uN, mask : uN):
      dst, m, k = ([], 0, 0)

      while m < nbits(a):
        if mask[m] == 1:
          dst.append(a[m])
          k += 1
        m += 1

      return uN(dst)
    ```

    ```python
    def find$pext[entries: array](key : any, unknown: any):
      # 0. find mask which uniquely identifies all keys [compile-time]
      mask = 0b111111...

      for i in range(nbits(mask)):
        masked = []
        mask.unset(i)

        for k, v in entries:
          masked.append(k & mask)

        if not unique(masked):
          mask.set(i)

      assert unique(masked)
      assert mask != ~mask{}

      # 1. create lookup table [compile-time]
      lookup = array(typeof(entries[0]), 2**popcount(mask))
      for k, v in entries:
        lookup[pext(k, mask)] = (k, v)

      # 2. lookup [run-time] # if key is a string convert to integral first (memcpy)
      k, v = lookup[pext(key, mask)]

      if k == key: # cmove
        return v
      else:
        return unknown
    ```

    ```python
    def find$simd[entries: array](key : any, unknown: any):
      # 0. find mask which uniquely identifies all keys [compile-time]
      mask = 0b111111...
      bucket_size = simd_size_v<entries[0].first, native>

      for i in range(nbits(mask)):
        masked = []
        mask.unset(i)

        for k, v in entries:
          masked.append(k & mask)

        if not unique(masked, bucket_size):
          mask.set(i)

      assert unique(masked, bucket_size)
      assert mask != ~mask{}

      # 1. create lookup table [compile-time]
      keys   = array(typeof(entries[0].first), bucket_size * 2**popcount(mask))
      values = array(typeof(entries[0].second), bucket_size * 2**popcount(mask))
      for k, v in entries:
        slot = pext(k, mask)
        while (keys[slot]) slot++;
        keys[slot] = k
        values[slot] = v

      # 2. lookup [run-time] # if key is a string convert to integral first (memcpy)
      index = bucket_size * pext(key, mask)
      match = k == keys[&index] # simd element-wise comparison

      if any_of(match):
        return values[index + find_first_set(match)]
      else:
        return unknown
    ```

    > More information - https://krzysztof-jusiak.github.io/talks/cpponsea2024

- How to tweak `lookup/find` performance for my data/use case?

    > Always measure!

  - [[bmi2](https://en.wikipedia.org/wiki/X86_Bit_manipulation_instruction_set) ([Intel Haswell](Intel)+, [AMD Zen3](https://en.wikipedia.org/wiki/Zen_3)+)] hardware instruction acceleration is faster than software emulation. (AMD Zen2 pext takes 18 cycles, is worth disabling hardware accelerated version)
  - For integral keys, use u32 or u64.
  - For strings, consider aligning the input data and passing it with compile-time size via `span`, `array`.
  - If all strings length is less than 4 that will be more optimized than if all string length will be less than 8 and 16. That will make the lookup table smaller and getting the value will have one instruction less.
  - Experiment with different `probability` values to optimize lookups. Especially benefitial if its known that input keys are always coming from predefined `entries` (probability = 100) as it will avoid the comparison.
  - Consider passing cache size alignment (`hardware_destructive_interference_size` - usually `64u`) to the `lookup/find`. That will align the underlying lookup table.

- How to fix compilation error `constexpr evaluation hit maximum step limit`?

    > The following options can be used to increase the limits, however, compilation-times should be monitored.

    ```
    gcc:   -fconstexpr-ops-limit=N
    clang: -fconstexpr-steps=N
    ```

- Is support for [bmi2](https://en.wikipedia.org/wiki/X86_Bit_manipulation_instruction_set) instructions required?

    > `mph` works on platforms without `bmi2` instructions which can be emulated with some limitations (*).

    ```cpp
    // bmi2
    mov     ecx, 789
    pext    ecx, eax, ecx
    ```

    > [intel.com/pext](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html#text=pext) / [uops.info/pext](https://uops.info/table.html?search=PEXT%20(R64%2C%20R64%2C%20R64)&cb_lat=on&cb_HSW=on&cb_BDW=on&cb_SKL=on&cb_CFL=on&cb_CLX=on&cb_ICL=on&cb_TGL=on&cb_RKL=on&cb_ZEN2=on&cb_ZEN3=on&cb_ZEN4=on&cb_measurements=on&cb_bmi=on)

    ```cpp
    // no bmi2
    mov     ecx, eax
    and     ecx, 789
    imul    ecx, ecx, 57
    shr     ecx, 2
    and     ecx, 248
    ```

    > https://stackoverflow.com/questions/14547087/extracting-bits-with-a-single-multiplication (*)

- How to disable `cmov` generation?

    > Set `probability` value to something else than `50u` (default) - it means that the input data is predictable in some way and `jmp` will be generated instead. Additionaly the following compiler options can be used.

    ```
    clang: -mllvm -x86-cmov-converter=false
    ```

- How to disable running tests at compile-time?

    > When `-DNTEST` is defined static_asserts tests wont be executed upon inclusion.
      Note: Use with caution as disabling tests means that there are no gurantees upon inclusion that given compiler/env combination works as expected.

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name mph
      GITHUB_REPOSITORY qlibs/mph
      GIT_TAG v5.0.1
    )
    add_library(mph INTERFACE)
    target_include_directories(mph SYSTEM INTERFACE ${mph_SOURCE_DIR})
    add_library(mph::mph ALIAS mph)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} mph::mph);
    ```

- Similar projects?

    > [gperf](https://www.gnu.org/software/gperf), [frozen](https://github.com/serge-sans-paille/frozen), [nbperf](https://github.com/rurban/nbperf), [cmph](https://cmph.sourceforge.net), [perfecthash](https://github.com/tpn/perfecthash), [lemonhash](https://github.com/ByteHamster/LeMonHash), [pthash](https://github.com/jermp/pthash), [shockhash](https://github.com/ByteHamster/ShockHash), [burr](https://github.com/lorenzhs/BuRR), [hash-prospector](https://github.com/skeeto/hash-prospector)

- Acknowledgments

    > https://lemire.me/blog, http://0x80.pl, https://easyperf.net, https://www.jabperf.com, https://johnnysswlab.com, [pefect-hashing](https://github.com/tpn/pdfs/tree/master/Perfect%20Hashing), [gperf](https://www.dre.vanderbilt.edu/~schmidt/PDF/C++-USENIX-90.pdf), [cmph](https://cmph.sourceforge.net/papers), [smasher](https://github.com/rurban/smhasher), [minimal perfect hashing](http://stevehanov.ca/blog/index.php?id=119), [hash functions](https://nullprogram.com/blog/2018/07/31)
---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Freflect.svg)](https://github.com/qlibs/reflect/releases)
[![build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/zvooxGPP9)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/oYhh1hfeo)

---------------------------------------

## reflect: C++20 Static Reflection library

> https://en.wikipedia.org/wiki/Reflective_programming

### Features

- Single header (https://raw.githubusercontent.com/qlibs/reflect/main/reflect - for integration see [FAQ](#faq))
- Minimal [API](#api)
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))
    - Basically guarantees no UB, no memory leaks*
- Compiles cleanly with ([`-fno-exceptions -fno-rtti -Wall -Wextra -Werror -pedantic -pedantic-errors | /W4 /WX`](https://godbolt.org/z/M747ocGfx))
- Agnostic to compiler changes (no ifdefs for the compiler specific implementations - see [FAQ](#faq))
- Optimized run-time execution and binary size (see [performance](#perf))
- Fast compilation times (see [compilation times](#comp))

### Requirements

- C++20 ([gcc-12+, clang-15+, msvc-19.36+](https://godbolt.org/z/xPc19Moef))
    - STL headers (array, string_view, source_location, type_traits, utility, [tuple])

---

### Hello world (https://godbolt.org/z/oYhh1hfeo)

```cpp
#include <reflect>

enum E { A, B };
struct foo { int a; E b; };

constexpr auto f = foo{.a = 42, .b = B};

// reflect::size
static_assert(2 == reflect::size(f));

// reflect::type_id
static_assert(reflect::type_id(f.a) != reflect::type_id(f.b));

// reflect::type_name
static_assert("foo"sv == reflect::type_name(f));
static_assert("int"sv == reflect::type_name(f.a));
static_assert("E"sv   == reflect::type_name(f.b));

// reflect::enum_name
static_assert("B"sv == reflect::enum_name(f.b));

// reflect::member_name
static_assert("a"sv == reflect::member_name<0>(f));
static_assert("b"sv == reflect::member_name<1>(f));

// reflect::get
static_assert(42 == reflect::get<0>(f)); // by index
static_assert(B  == reflect::get<1>(f));

static_assert(42 == reflect::get<"a">(f)); // by name
static_assert(B  == reflect::get<"b">(f));

// reflect::to
constexpr auto t = reflect::to<std::tuple>(f);
static_assert(42 == std::get<0>(t));
static_assert(B  == std::get<1>(t));

int main() {
  reflect::for_each([](auto I) {
    std::print("{}.{}:{}={} ({}/{}/{})\n",
        reflect::type_name(f),                  // foo, foo
        reflect::member_name<I>(f),             // a  , b
        reflect::type_name(reflect::get<I>(f)), // int, E
        reflect::get<I>(f),                     // 42 , B
        reflect::size_of<I>(f),                 // 4  , 4
        reflect::align_of<I>(f),                // 4  , 4
        reflect::offset_of<I>(f));              // 0  , 4
  }, f);
}

// and more (see API)...
```

---

### Examples

- [feature] Opt-in mixins - https://godbolt.org/z/sj7fYKoc3
- [feature] Meta-programming (https://github.com/qlibs/mp) - https://godbolt.org/z/ds3KMGhqP
- [future] Structured Bindings can introduce a Pack (https://wg21.link/P1061) - https://godbolt.org/z/Ga3bc3KKW
- [performance] Minimal Perfect Hashing based `enum_name` (https://github.com/qlibs/mph) - https://godbolt.org/z/WM155vTfv

---

<a name="perf"></a>
### Performance/Binary size (https://godbolt.org/z/7TbobjWfj)

```cpp
struct foo { int bar; };
auto type_name(const foo& f) { return reflect::type_name(f); }
```

```asm
type_name(foo const&): // $CXX -O3 -DNDEBUG
        lea     rdx, [rip + type_name<foo>]
        mov     eax, 3
        ret

type_name<foo>
        .ascii  "foo"
```

```cpp
struct foo { int bar; };
auto member_name(const foo& f) { return reflect::member_name<0>(f); }
```

```asm
member_name(foo const&): // $CXX -O3 -DNDEBUG
        lea     rdx, [rip + member_name<0ul, foo>]
        mov     eax, 3
        ret

member_name<0ul, foo>
        .ascii  "bar"
```

```cpp
enum class E { A, B, };
auto enum_name(const E e) { return reflect::enum_name(e); }
```

```asm
enum_name(E): // $CXX -O3 -DNDEBUG (generates switch)
        xor     eax, eax
        xor     ecx, ecx
        cmp     edi, 1
        sete    cl
        lea     rdx, [rip + enum_name<0>]
        cmove   rax, rdx
        test    edi, edi
        lea     rdx, [rip + enum_name<1>]
        cmovne  rdx, rax
        mov     eax, 1
        cmovne  rax, rcx
        ret

enum_name<0ul>:
        .ascii  "A"

enum_name<1ul>:
        .ascii  "B"
```

<a name="comp"></a>
### Compilation times

> [include] https://raw.githubusercontent.com/qlibs/reflect/main/reflect

```cpp
time g++-13.2 -x c++ -std=c++20 reflect -c -DNTEST   # 0.113s
time g++-13.2 -x c++ -std=c++20 reflect -c           # 0.253s
```

```cpp
time clang++-17 -x c++ -std=c++20 reflect -c -DNTEST # 0.119s
time clang++-17 -x c++ -std=c++20 reflect -c         # 0.322s
```

---

### API

```cpp
template <class Fn, class T> requires std::is_aggregate_v<std::remove_cvref_t<T>>
[[nodiscard]] constexpr auto visit(Fn&& fn, T&& t) noexcept;
```

```cpp
struct foo { int a; int b; };
static_assert(2 == visit([](auto&&... args) { return sizeof...(args); }, foo{}));
```

```cpp
template<class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto size() -> std::size_t;

template<class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto size(const T&) -> std::size_t;
```

```cpp
struct foo { int a; int b; } f;
static_assert(2 == size<foo>());
static_assert(2 == size(f));
```

```cpp
template <class T> [[nodiscard]] constexpr auto type_name() noexcept;
template <class T> [[nodiscard]] constexpr auto type_name(const T&) noexcept;
```

```cpp
struct foo { int a; int b; };
static_assert(std::string_view{"foo"} == type_name<foo>());
static_assert(std::string_view{"foo"} == type_name(foo{}));
```

```cpp
template <class T> [[nodiscard]] constexpr auto type_id() noexcept;
template <class T> [[nodiscard]] constexpr auto type_id(T&&) noexcept;
```

```cpp
struct foo { };
struct bar { };
static_assert(type_id(foo{}) == type_id(foo{}));
static_assert(type_id(bar{}) != type_id<foo>());
```

```cpp
template<class E>
[[nodiscard]] constexpr auto to_underlying(const E e) noexcept;

template<class E> requires std::is_enum_v<E>
consteval auto enum_min(const E = {}) { return REFLECT_ENUM_MIN; }

template<class E> requires std::is_enum_v<E>
consteval auto enum_max(const E = {}) { return REFLECT_ENUM_MAX; }

template<class E,
         fixed_string unknown = "",
         auto Min = enum_min(E{}),
         auto Max = enum_max(E{})>
  requires (std::is_enum_v<E> and Max > Min)
[[nodiscard]] constexpr auto enum_name(const E e) noexcept -> std::string_view {
```

```cpp
enum class Enum { foo = 1, bar = 2 };
static_assert(std::string_view{"foo"} == enum_name(Enum::foo));
static_assert(std::string_view{"bar"} == enum_name(Enum::bar));
```

```cpp
enum class Enum { foo = 1, bar = 1024 };
consteval auto enum_min(Enum) { return Enum::foo; }
consteval auto enum_max(Enum) { return Enum::bar; }

static_assert(std::string_view{"foo"} == enum_name(Enum::foo));
static_assert(std::string_view{"bar"} == enum_name(Enum::bar));
```

```cpp
template <std::size_t N, class T>
  requires (std::is_aggregate_v<T> and N < size<T>())
[[nodiscard]] constexpr auto member_name(const T& = {}) noexcept;
```

```cpp
struct foo { int a; int b; };
static_assert(std::string_view{"a"} == member_name<0, foo>());
static_assert(std::string_view{"a"} == member_name<0>(foo{}));
static_assert(std::string_view{"b"} == member_name<1, foo>());
static_assert(std::string_view{"b"} == member_name<1>(foo{}));
```

```cpp
template<std::size_t N, class T>
  requires (std::is_aggregate_v<std::remove_cvref_t<T>> and
            N < size<std::remove_cvref_t<T>>())
[[nodiscard]] constexpr decltype(auto) get(T&& t) noexcept;
```

```cpp
struct foo { int a; bool b; };
constexpr auto f = foo{.i=42, .b=true};
static_assert(42 == get<0>(f));
static_assert(true == get<1>(f));
```

```cpp
template <class T, fixed_string Name> requires std::is_aggregate_v<T>
concept has_member_name = /*unspecified*/
```

```cpp
struct foo { int a; int b; };
static_assert(has_member_name<foo, "a">);
static_assert(has_member_name<foo, "b">);
static_assert(not has_member_name<foo, "c">);
```

```cpp
template<fixed_string Name, class T> requires has_member_name<T, Name>
constexpr decltype(auto) get(T&& t) noexcept;
```

```cpp
struct foo { int a; int b; };
constexpr auto f = foo{.i=42, .b=true};
static_assert(42 == get<"a">(f));
static_assert(true == get<"b">(f));
```

```cpp
template<fixed_string... Members, class TSrc, class TDst>
  requires (std::is_aggregate_v<TSrc> and std::is_aggregate_v<TDst>)
constexpr auto copy(const TSrc& src, TDst& dst) noexcept -> void;
```

```cpp
struct foo { int a; int b; };
struct bar { int a{}; int b{}; };

bar b{};
foo f{};

copy(f, b);
assert(b.a == f.a);
assert(b.b == f.b);

copy<"a">(f, b);
assert(b.a == f.a);
assert(0 == b.b);
```

```cpp
template<template<class...> class R, class T>
  requires std::is_aggregate_v<std::remove_cvref_t<T>>
[[nodiscard]] constexpr auto to(T&& t) noexcept;
```

```cpp
struct foo { int a; int b; };

constexpr auto t = to<std::tuple>(foo{.a=4, .b=2});
static_assert(4 == std::get<0>(t));
static_assert(2 == std::get<1>(t));

auto f = foo{.a=4, .b=2};
auto t = to<std::tuple>(f);
std::get<0>(t) *= 10;
f.b = 42;
assert(40 == std::get<0>(t) and 40 == f.a);
assert(42 == std::get<1>(t) and 42 == f.b);
```

```cpp
template<class R, class T>
[[nodiscard]] constexpr auto to(T&& t);
```

```cpp
struct foo { int a; int b; };
struct baz { int a{}; int c{}; };

const auto b = to<baz>(foo{.a=4, .b=2});
assert(4 == b.a and 0 == b.c);
```

```cpp
template<std::size_t N, class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto size_of() -> std::size_t;

template<std::size_t N, class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto size_of(T&&) -> std::size_t;

template<std::size_t N, class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto align_of() -> std::size_t;

template<std::size_t N, class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto align_of(T&&) -> std::size_t;

template<std::size_t N, class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto offset_of() -> std::size_t;

template<std::size_t N, class T> requires std::is_aggregate_v<T>
[[nodiscard]] constexpr auto offset_of(T&&) -> std::size_t;
```

```cpp
struct foo { int a; bool b; };

static_assert(4 == size_of<0, foo>());
static_assert(1 == size_of<1, foo>());
static_assert(4 == align_of<0, foo>());
static_assert(1 == align_of<1, foo>());
static_assert(0 == offset_of<0, foo>());
static_assert(4 == offset_of<1, foo>());
```

```cpp
template<class Fn, class T>
  requires std::is_aggregate_v<std::remove_cvref_t<T>>
constexpr auto for_each(Fn&& fn) -> void;

template<class Fn, class T>
  requires std::is_aggregate_v<std::remove_cvref_t<T>>
constexpr auto for_each(Fn&& fn, T&& t) -> void;
```

```cpp
struct { int a; int b; } f;

reflect::for_each([&f](const auto I) {
  std::print("{}:{}={}", member_name<I>(f), get<I>(f)); // prints a:int=4, b:int=2
}, f);
```

> Configuration

```cpp
#define REFLECT_ENUM_MIN 0      // Min size for enum name (can be overridden)
                                // For example: `-DREFLECT_ENUM_MIN=-1`
#define REFLECT_ENUM_MAX 128    // Max size for enum name (can be overridden)
                                // For example: `-DREFLECT_ENUM_MAX=32`
```

---

### FAQ

- How does `reflect` compare to https://wg21.link/P2996?

    > `reflect` library only provides basic reflection primitives, mostly via hacks and workarounds to deal with lack of the reflection.
    https://wg21.link/P2996 is a language proposal with many more features and capabilities.

- How does `reflect` work under the hood?

    > There are many different ways to implement reflection. `reflect` uses C++20's structure bindings, concepts and source_location to do it. See `visit` implementation for more details.

- How can `reflect` be agnostic to compiler changes?

    > `reflect` precomputes required prefixes/postfixes to find required names from the `source_location::function_name()` output for each compiler upon inclusion.
    Any compiler change will end up with new prefixes/postfixes and wont require additional maintenance.

- What does it mean that `reflect` tests itself upon include?

    > `reflect` runs all tests (via static_asserts) upon include. If the include compiles it means all tests are passing and the library works correctly on given compiler, environment.

- What is compile-time overhead of `reflect` library?

    > `reflect` include takes ~.2s (that includes running all tests).
    The most expensive calls are `visit` and `enum_to_name` whose timing will depend on the number of reflected elements and/or min/max values provided.
    There are no recursive template instantiations in the library.

- Can I disable running tests at compile-time for faster compilation times?

    > When `-DNTEST` is defined static_asserts tests wont be executed upon inclusion.
    Note: Use with caution as disabling tests means that there are no guarantees upon inclusion that the given compiler/env combination works as expected.

- How to extend the number of members to be reflected (default: 64)?

    > Override `visit`, for example - https://godbolt.org/z/Ga3bc3KKW

    ```cpp
    template <class Fn, class T> // requires https://wg21.link/P1061
    [[nodiscard]] constexpr decltype(auto) visit(Fn&& fn, T&& t) noexcept {
      auto&& [... ts] = std::forward<T>(t);
      return std::forward<Fn>(fn)(std::forward_like<T>(ts)...);
    }
    ```

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name reflect
      GITHUB_REPOSITORY qlibs/reflect
      GIT_TAG v1.2.2
    )
    add_library(reflect INTERFACE)
    target_include_directories(reflect SYSTEM INTERFACE ${reflect_SOURCE_DIR})
    add_library(reflect::reflect ALIAS reflect)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} reflect::reflect);
    ```

- Similar projects?
    > [boost.pfr](https://github.com/boostorg/pfr), [glaze](https://github.com/stephenberry/glaze), [reflect-cpp](https://github.com/getml/reflect-cpp), [magic_enum](https://github.com/Neargye/magic_enum)
---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fut.svg)](https://github.com/qlibs/sml/releases)
[![build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/Gcfncoo6r)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/44YrGeqbx)

---------------------------------------

## SML: UML-2.5 State Machine Language

> https://en.wikipedia.org/wiki/Finite-state_machine

### Features

- Single header (https://raw.githubusercontent.com/qlibs/sml/main/sml)
    - Easy integration (see [FAQ](#faq))
- Verifies itself upon include (aka run all tests via static_asserts but it can be disabled - see [FAQ](#faq))
* Optimized run-time execution and binary size (see [performance](https://godbolt.org/z/W9rP94cYK))
* Fast compilation times (see [benchmarks](https://github.com/qlibs/sml/blob/gh-pages/images/sml2.perf.png))
* Declarative Domain Specific Language (see [API](#api))

### Requirements

- C++20 ([Clang-15+, GCC-12+](https://en.cppreference.com/w/cpp/compiler_support))

    - No dependencies (Neither Boost nor STL is required)
    - No `virtual` used (-fno-rtti)
    - No `exceptions` required (-fno-exceptions)

---

<p align="center"><img src="https://github.com/qlibs/sml/blob/gh-pages/images/example.png" /></p>

```cpp
// events
struct connect {};
struct ping { bool valid = false; };
struct established {};
struct timeout {};
struct disconnect {};

int main() {
  // state machine
  sml::sm connection = [] {
    // guards
    auto is_valid  = [](const auto& event) { return event.valid; };

    // actions
    auto establish = [] { std::puts("establish"); };
    auto close     = [] { std::puts("close"); };
    auto setup     = [] { std::puts("setup"); };

    using namespace sml::dsl;
    /**
     * src_state + event [ guard ] / action = dst_state
     */
    return transition_table{
      *"Disconnected"_s + event<connect> / establish    = "Connecting"_s,
       "Connecting"_s   + event<established>            = "Connected"_s,
       "Connected"_s    + event<ping>[is_valid] / setup,
       "Connected"_s    + event<timeout> / establish    = "Connecting"_s,
       "Connected"_s    + event<disconnect> / close     = "Disconnected"_s,
    };
  };

  connection.process_event(connect{});
  connection.process_event(established{});
  connection.process_event(ping{.valid = true});
  connection.process_event(disconnect{});
}
```

---

### FAQ

- Why would I use a state machine?

    > State machine helps with understanding of the application flow as well as with avoiding spaghetti code.
      The more booleans/enums/conditions there are the harder is to understand the implicit state of the program.
      State machines make the state explicit which makes the code easier to follow,change and maintain.
      Its worth noticing that state machines are not required by any means (there is no silver bullet),
      switch-case, if-else, co-routines, state pattern, etc. can be used instead. Use your own judgment and
      experience when choosing a solution based its trade-offs.

- What UML2.5 features are supported and what features will be supported?

    > ATM `SML` supports basic UML features such as transitions, processing events, unexpected events, etc.
      Please follow tests/examples to stay up to date with available features - https://github.com/qlibs/sml/blob/main/sml#L388
      There is plan to add more features, potentially up to full UML-2.5 support.

- How does it compare to implementing state machines with co-routines?

   > Its a different approach. Either has its pros and cons. Co-routines are easier to be executed in parallel but they have performance overhead.
     Co-routines based state machines are written in imperative style whilst SML is using declarative Domain Specific Language (DSL).
     More information can be found here - https://youtu.be/Zb6xcd2as6o?t=1529

- SML vs UML?

    > `SML` follows UML-2.5 - http://www.omg.org/spec/UML/2.5 - as closeily as possible but it has limited features ATM.

- Can I use `SML` at compile-time?

    > Yes. `SML` is fully compile-time but it can be executed at run-time as well. The run-time is primary use case for `SML`.

- Can I disable running tests at compile-time for faster compilation times?

    > When `NTEST` is defined static_asserts tests wont be executed upon inclusion.
    Note: Use with caution as disabling tests means that there are no guarantees upon inclusion that the given compiler/env combination works as expected.

- Is `SML` SFINAE friendly?

    > Yes, `SML` is SFINAE (Substitution Failure Is Not An Error) friendly, especially the call to `process_event`.

- How to pass dependencies to guards/actions?

    ```cpp
    struct foo {
      bool value{};

      constexpr auto operator()() const {
        auto guard = [this] { return value; }; // dependency capctured by this
        return transition_table{
            *"s1"_s + event<e1>[guard] = "s2"_s,
        };
      }
    };

    sml::sm sm{foo{.value = 42}); // inject value into foo
    ```

- Is `SML` suitable for embedded systems?

    > Yes, `SML` doesnt have any extenal dependencies, compiles without RTTI and without exceptions.
      Its also focused on performance, binary size and memory footprint.
      The following command compiiles without issues:
      `$CXX -std=c++20 -Ofast -fno-rtti -fno-exceptions -Wall -Wextra -Werror -pedantic -pedantic-errors example.cpp`

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name sml
      GITHUB_REPOSITORY qlibs/sml
      GIT_TAG v2.0.0
    )
    add_library(sml INTERFACE)
    target_include_directories(sml SYSTEM INTERFACE ${sml_SOURCE_DIR})
    add_library(sml::sml ALIAS sml)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} sml::sml);
    ```

- Is there a Rust version?

    > Rust - `SML` version can be found here - https://gist.github.com/krzysztof-jusiak/079f80e9d8c472b2c8d515cbf07ad665
---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fswar.svg)](https://github.com/qlibs/swar/releases)
[![Build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/xob1nGYoP)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/55K55hqWb)

---------------------------------------

## SWAR: [SIMD](https://en.wikipedia.org/wiki/Single_instruction,_multiple_data) within a register library

> https://en.wikipedia.org/wiki/SWAR

### Use cases

- Performance (branchless)
- Portable (uses 'normal' registers)

### Features

- Single header (https://raw.githubusercontent.com/qlibs/swar/main/swar - for integration see [FAQ](#faq))
- Minimal [API](#api)
- Verifies itself upon include (can be disabled with `-DNTEST` - see [FAQ](#faq))

### Requirements

- C++20 ([clang++13+, g++12](https://en.cppreference.com/w/cpp/compiler_support))

---

### Overview

> API (https://godbolt.org/z/b4v9aTEYs)

```cpp
constexpr u8 data[]{1, 2, 3, 5, 5, 6, 7, 8};
constexpr swar<u8> lhs{data}; // copy_from
constexpr swar<u8> rhs{5};    // broadcast (native: u64)

static_assert(8u == lhs.size());
static_assert(sizeof(u64) == sizeof(lhs));

constexpr auto match = lhs == rhs;

static_assert(any_of(match));
static_assert(some_of(match));
static_assert(not all_of(match));
static_assert(not none_of(match));

static_assert(3u == find_first_set(match));
static_assert(4u == find_last_set(match));
static_assert(2u == popcount(match));
static_assert(match[3u] and match[4u]);

static_assert(sizeof(u32)  == sizeof(swar<u8,  4u>));
static_assert(sizeof(u64)  == sizeof(swar<u8,  8u>));
static_assert(sizeof(u32)  == sizeof(swar<u16, 2u>));
static_assert(sizeof(u64)  == sizeof(swar<u16, 4u>));
static_assert(sizeof(u64)  == sizeof(swar<u32, 2u>));
static_assert(sizeof(u128) == sizeof(swar<u32, 4u>));

// and more (see API)...
```

> Performance (https://godbolt.org/z/ManGb8aso)

```cpp
auto eq(swar<u8> lhs, swar<u8> rhs) {
  return lhs == rhs;
}
```

```cpp
eq: // $CXX -O3 -mno-sse -mno-sse2 -mno-sse3 -mno-avx
  movabs  rdx, -9187201950435737472
  xor     rdi, rsi
  movabs  rax, 72340172838076672
  or      rdi, rdx
  sub     rax, rdi
  and     rax, rdx
  ret
```

```cpp
auto contains(swar<u8> lhs, u8 value) {
  const auto rhs = swar<u8>{value};
  const auto match = lhs == rhs;
  return any_of(match);
}
```

```cpp
contains: // $CXX -O3 -mno-sse -mno-sse2 -mno-sse3 -mno-avx
  movabs  rax, 72340172838076673
  movzx   esi, sil
  movabs  rdx, -9187201950435737472
  imul    rsi, rax
  sub     rax, 1
  xor     rdi, rsi
  or      rdi, rdx
  sub     rax, rdi
  test    rax, rdx
  setne   al
  ret
```

```cpp
auto find(swar<u8> lhs, u8 value) {
  const auto rhs = swar<u8>{value};
  const auto match = lhs == rhs;
  return any_of(match) * find_first_set(match);
}
```

```cpp
find: // $CXX -O3 -mno-sse -mno-sse2 -mno-sse3 -mno-avx
  movabs  rax, 72340172838076673
  movzx   esi, sil
  movabs  rdx, 72340172838076672
  imul    rsi, rax
  movabs  rax, -9187201950435737472
  xor     rdi, rsi
  or      rdi, rax
  sub     rdx, rdi
  and     rdx, rax
  xor     eax, eax
  rep bsf rax, rdx
  test    rdx, rdx
  mov     edx, 0
  cmove   rax, rdx
  ret
```

---

### Examples

> swar vs simd (https://godbolt.org/z/YsG8evqr8)

```cpp
template<class T> auto eq(T lhs, T rhs) { return lhs == rhs; }
```

```cpp
eq(swar<u8>, swar<u8>): // $CXX -O3 -mno-sse -mno-sse2 -mno-sse3 -mno-avx
  movabs  rdx, -9187201950435737472
  xor     rdi, rsi
  movabs  rax, 72340172838076672
  or      rdi, rdx
  sub     rax, rdi
  and     rax, rdx
  ret

eq(simd<u8>, simd<u8>): // $CXX -O3 -mavx512f
  vpcmpeqb xmm0, xmm0, xmm1
  ret
```

```cpp
template<class T> auto contains(T lhs, auto value) {
  const auto rhs = T{value};
  const auto match = lhs == rhs;
  return any_of(match);
}
```

```cpp
cointains(swar<u8>, swar<u8>): // $CXX -O3 -mno-sse -mno-sse2 -mno-sse3 -mno-avx
  movabs  rax, 72340172838076673
  movzx   esi, sil
  movabs  rdx, -9187201950435737472
  imul    rsi, rax
  sub     rax, 1
  xor     rdi, rsi
  or      rdi, rdx
  sub     rax, rdi
  test    rax, rdx
  setne   al
  ret

contains(simd<u8>, simd<u8>): // $CXX -O3 -mavx512f
  vmovd        xmm1, edi
  vpbroadcastb xmm1, xmm1
  vpcmpeqb     xmm0, xmm1, xmm0
  vptest       xmm0, xmm0
  setne        al
  ret
```


```cpp
template<class T> auto find(T lhs, auto value) {
  const auto rhs = T{value};
  const auto match = lhs == rhs;
  return any_of(match) * find_first_set(match);
}
```

```cpp
find(swar<u8>, swar<u8>): // $CXX -O3 -mno-sse -mno-sse2 -mno-sse3 -mno-avx
  movabs  rax, 72340172838076673
  movzx   esi, sil
  movabs  rdx, 72340172838076672
  imul    rsi, rax
  movabs  rax, -9187201950435737472
  xor     rdi, rsi
  or      rdi, rax
  sub     rdx, rdi
  and     rdx, rax
  xor     eax, eax
  rep bsf rax, rdx
  test    rdx, rdx
  mov     edx, 0
  cmove   rax, rdx
  ret

find(simd<u8>, simd<u8>): // $CXX -O3 -mavx512f
  vmovd         xmm1, edi
  vpbroadcastb  xmm1, xmm1
  vpcmpeqb      xmm0, xmm1, xmm0
  vpmovmskb     eax, xmm0
  or            eax, 65536
  rep           bsf ecx, eax
  xor           eax, eax
  vptest        xmm0, xmm0
  cmovne        eax, ecx
  ret
```

---

### API

```cpp
template<class T, size_t Width = sizeof(u64) / sizeof(T), class TAbi = abi_t<T, Width>>
  requires ((sizeof(T) * Width) <= sizeof(TAbi))
struct swar {
  using value_type = T;
  using abi_type = TAbi;

  constexpr swar() noexcept = default;
  constexpr swar(const swar&) noexcept = default;
  constexpr swar(swar&&) noexcept = default;
  constexpr explicit swar(const auto value) noexcept;
  constexpr explicit swar(const auto* mem) noexcept;
  constexpr explicit swar(const auto& gen) noexcept;
  [[nodiscard]] constexpr explicit operator abi_type() const noexcept;
  [[nodiscard]] constexpr auto operator[](size_t) const noexcept -> T;
  [[nodiscard]] static constexpr auto size() noexcept -> size_t;
  [[nodiscard]] friend constexpr auto operator==(const swar&, const swar&) noexcept;
};

template<class T, size_t Width = sizeof(u64) / sizeof(T), class TAbi = abi_t<T, Width>>
  requires ((sizeof(T) * Width) <= sizeof(TAbi))
struct swar_mask {
  using value_type = bool; /// predefined
  using abi_type = TAbi;

  constexpr swar_mask() noexcept = default;
  constexpr swar_mask(const swar_mask&) noexcept = default;
  constexpr swar_mask(swar_mask&&) noexcept = default;
  constexpr explicit swar_mask(const abi_type value) noexcept;

  [[nodiscard]] constexpr auto operator[](const size_t index) const noexcept -> bool;
  [[nodiscard]] static constexpr auto size() noexcept -> size_t { return Width; }
};

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto all_of(const swar_mask<T, Width, TAbi>& s) noexcept -> bool;

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto any_of(const swar_mask<T, Width, TAbi>& s) noexcept -> bool;

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto some_of(const swar_mask<T, Width, TAbi>& s) noexcept -> bool;

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto none_of(const swar_mask<T, Width, TAbi>& s) noexcept -> bool;

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto find_first_set(const swar_mask<T, Width, TAbi>& s) noexcept;

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto find_last_set(const swar_mask<T, Width, TAbi>& s) noexcept;

template<class T, size_t Width, class TAbi>
[[nodiscard]] constexpr auto popcount(const swar_mask<T, Width, TAbi>& s) noexcept;

template<class T> inline constexpr bool is_swar_v = /* unspecified */;
template<class T> inline constexpr bool is_swar_mask_v = /* unspecified */;
```

---

### FAQ

- How to disable running tests at compile-time?

    > When `-DNTEST` is defined static_asserts tests wont be executed upon include.
    Note: Use with caution as disabling tests means that there are no gurantees upon include that given compiler/env combination works as expected.

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name swar
      GITHUB_REPOSITORY qlibs/swar
      GIT_TAG v1.0.0
    )
    add_library(swar INTERFACE)
    target_include_directories(swar SYSTEM INTERFACE ${swar_SOURCE_DIR})
    add_library(swar::swar ALIAS swar)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} swar::swar);
    ```

- Acknowledgments

  > https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html, https://wg21.link/P1928
---
[![MIT Licence](http://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/mit)
[![Version](https://badge.fury.io/gh/qlibs%2Fut.svg)](https://github.com/qlibs/ut/releases)
[![build](https://img.shields.io/badge/build-blue.svg)](https://godbolt.org/z/f3WPzK5xf)
[![Try it online](https://img.shields.io/badge/try%20it-online-blue.svg)](https://godbolt.org/z/MG5cjnsbM)

---------------------------------------

> "If you liked it then you `"should have put a"_test` on it", Beyonce rule

## UT: C++20 minimal unit-testing library

> https://en.wikipedia.org/wiki/Unit_testing

### Features

- Single header (https://raw.githubusercontent.com/qliqbs/ut/main/ut)
    - Easy integration (see [FAQ](#faq))
- Compile-time first (executes tests at compile-time and/or run-time)
    - Detects memory leaks and UBs at compile-time*
- Explicit by design (no implicit conversions, narrowing, epsilon-less floating point comparisions, ...)
- Minimal [API](#api)
- Reflection integration (optional via https://github.com/qlibs/reflect)
- Compiles cleanly with ([`-fno-exceptions -fno-rtti -Wall -Wextra -Werror -pedantic -pedantic-errors`](https://godbolt.org/z/ceK6qsx68))
- Fast compilation times (see [compilation times](#comp))
- Fast run-time execution (see [performance](#perf))
- Verifies itself upon include (aka run all tests via static_asserts but it can be disabled - see [FAQ](#faq))

> Based on the `constexpr` ability of given compiler/standard

### Requirements

- C++20 ([gcc-12+, clang-16+](https://en.cppreference.com/w/cpp/compiler_support))

---

### Examples

> Hello world (https://godbolt.org/z/MG5cjnsbM)

```cpp
#include <ut>
#include <iostream> // output at run-time

constexpr auto sum(auto... args) { return (args + ...); }

int main() {
  using namespace ut;

  "sum"_test = [] {
    expect(sum(1) == 1_i);
    expect(sum(1, 2) == 3_i);
    expect(sum(1, 2, 3) == 6_i);
  };
}
```

```sh
$CXX example.cpp -std=c++20 -o example && ./example
PASSED: tests: 1 (1 passed, 0 failed, 1 compile-time), asserts: 3 (3 passed, 0 failed)
```

> Execution model (https://godbolt.org/z/31Gc151Mf)

```cpp
static_assert(("sum"_test = [] { // compile-time only
  expect(sum(1, 2, 3) == 6_i);
}));

int main() {
  "sum"_test = [] {              // compile time and run-time
    expect(sum(1, 2, 3) == 5_i);
  };

  "sum"_test = [] constexpr {    // compile-time and run-time
    expect(sum(1, 2, 3) == 6_i);
  };

  "sum"_test = [] mutable {      // run-time only
    expect(sum(1, 2, 3) == 6_i);
  };

  "sum"_test = [] consteval {    // compile-time only
    expect(sum(1, 2, 3) == 6_i);
  };
}
```

```sh
$CXX example.cpp -std=c++20 # -DUT_COMPILE_TIME_ONLY
ut:156:25: error: static_assert((test(), "[FAILED]"));
example.cpp:13:44: note:"sum"_test
example.cpp:14:5:  note: in call to 'expect.operator()<ut::eq<int, int>>({6, 5})'
```

```sh
$CXX example.cpp -std=c++20 -o example -DUT_RUNTIME_ONLY && ./example
example.cpp:14:FAILED:"sum": 6 == 5
FAILED: tests: 3 (2 passed, 1 failed, 0 compile-time), asserts: 2 (1 passed, 1 failed)
```

> Constant evaluation (https://godbolt.org/z/6E86YdbdT)

```cpp
constexpr auto test() {
  if consteval { return 42; } else { return 87; }
}

int main() {
  "compile-time"_test = [] consteval {
    expect(42_i == test());
  };

  "run-time"_test = [] mutable {
    expect(87_i == test());
  };
}
```

```sh
$CXX example.cpp -std=c++20 -o example && ./example
PASSED: tests: 2 (2 passed, 0 failed, 1 compile-time), asserts: 1 (1 passed, 0 failed)
```

> Suites/Sub-tests (https://godbolt.org/z/1oT3Gre93)

```cpp
ut::suite test_suite = [] {
  "vector [sub-tests]"_test = [] {
    std::vector<int> v(5);
    expect(v.size() == 5_ul);
    expect(v.capacity() >= 5_ul);

    "resizing bigger changes size and capacity"_test = [=] {
      mut(v).resize(10);
      expect(v.size() == 10_ul);
      expect(v.capacity() >= 10_ul);
    };
  };
};

int main() { }
```

```sh
$CXX example.cpp -std=c++20 -o example && ./example
PASSED: tests: 2 (2 passed, 0 failed, 1 compile-time), asserts: 4 (4 passed, 0 failed)
```

> Assertions (https://godbolt.org/z/79M7o355a)

```cpp
int main() {
  "expect"_test = [] {
    "different ways"_test = [] {
      expect(42_i == 42);
      expect(eq(42, 42))   << "same as expect(42_i == 42)";
      expect(_i(42) == 42) << "same as expect(42_i == 42)";
    };

    "floating point"_test = [] {
      expect((4.2 == 4.2_d)(.01)) << "floating point comparison with .01 epsilon precision";
    };

    "fatal"_test = [] mutable { // at run-time
      std::vector<int> v{1};
      expect[v.size() > 1_ul] << "fatal, aborts further execution";
      expect(v[1] == 42_i); // not executed
    };

    "compile-time expression"_test = [] {
      expect(constant<42 == 42_i>) << "requires compile-time expression";
    };
  };
}
```

```sh
$CXX example.cpp -std=c++20 -o example && ./example
example.cpp:21:FAILED:"fatal": 1 > 1
FAILED: tests: 3 (2 passed, 1 failed, 3 compile-time), asserts: 5 (4 passed, 1 failed)
```

> Errors/Checks (https://godbolt.org/z/Tvnce9j4d)

```cpp
int main() {
  "leak"_test = [] {
    new int; // compile-time error
  };

  "ub"_test = [] {
    int* i{};
    *i = 42; // compile-time error
  };

  "errors"_test = [] {
    expect(42_i == short(42)); // [ERROR] Comparision of different types is not allowed
    expect(42 == 42);          // [ERROR] Expression required: expect(42_i == 42)
    expect(4.2 == 4.2_d);      // [ERROR] Epsilon is required: expect((4.2 == 4.2_d)(.01))
  };
}
```

---

> Reflection integration (https://godbolt.org/z/v8GG4hfbW)

```cpp
int main() {
  struct foo { int a; int b; };
  struct bar { int a; int b; };

  "reflection"_test = [] {
    auto f = foo{.a=1, .b=2};
    expect(eq(foo{1, 2}, f));
    expect(members(foo{1, 2}) == members(f));
    expect(names(foo{}) == names(bar{}));
  };
};
```

```sh
$CXX example.cpp -std=c++20 -o example && ./example
PASSED: tests: 1 (1 passed, 0 failed, 1 compile-time), asserts: 3 (3 passed, 0 failed)
```

> Custom configuration (https://godbolt.org/z/6MrEEvqja)

```cpp
struct outputter {
  template<ut::events::mode Mode>
  constexpr auto on(const ut::events::test_begin<Mode>&) { }
  template<ut::events::mode Mode>
  constexpr auto on(const ut::events::test_end<Mode>&) { }
  template<class TExpr>
  constexpr auto on(const ut::events::assert_pass<TExpr>&) { }
  template<class TExpr>
  constexpr auto on(const ut::events::assert_fail<TExpr>&) { }
  constexpr auto on(const ut::events::fatal&) { }
  constexpr auto on(const ut::events::summary&) { }
  template<class TMsg>
  constexpr auto on(const ut::events::log<TMsg>&) { }
};

struct custom_config {
  ::outputter outputter{};
  ut::reporter<decltype(outputter)> reporter{outputter};
  ut::runner<decltype(reporter)> runner{reporter};
};

template<>
auto ut::cfg<ut::override> = custom_config{};

int main() {
  "config"_test = [] mutable {
    expect(42 == 43_i); // no output
  };
};
```

```sh
$CXX example.cpp -std=c++20 -o example && ./example
echo $? # 139 # no output
```

---

<a name="comp"></a>
### Compilation times

> Include - no iostream (https://raw.githubusercontent.com/qlibs/ut/main/ut)

```cpp
time $CXX -x c++ -std=c++20 ut -c -DNTEST          # 0.028s
time $CXX -x c++ -std=c++20 ut -c                  # 0.049s
```

> Benchmark - 100 tests, 1000 asserts (https://godbolt.org/z/zs5Ee3E7o)

```cpp
[ut]: time $CXX benchmark.cpp -std=c++20           # 0m0.813s
[ut]: time $CXX benchmark.cpp -std=c++20 -DNTEST   # 0m0.758s
-------------------------------------------------------------------------
[ut] https://github.com/qlibs/ut/releases/tag/v2.1.2
```

<a name="perf"></a>
### Performance

> Benchmark - 100 tests, 1000 asserts (https://godbolt.org/z/xKx45s4xq)

```cpp
time ./benchmark # 0m0.002s (-O3)
time ./benchmark # 0m0.013s (-g)
```

> X86-64 assembly -O3 (https://godbolt.org/z/rqbsafaE6)

```cpp
int main() {
  "sum"_test = [] {
    expect(42_i == 42);
  };
}
```

```cpp
main:
  mov  rax, qword ptr [rip + cfg<ut::override>+136]
  inc  dword ptr [rax + 24]
  mov  ecx, dword ptr [rax + 8]
  mov  edx, dword ptr [rax + 92]
  lea  esi, [rdx + 1]
  mov  dword ptr [rax + 92], esi
  mov  dword ptr [rax + 4*rdx + 28], ecx
  mov  rax, qword ptr [rax]
  lea  rcx, [rip + .L.str]
  mov  qword ptr [rax + 8], rcx
  mov  dword ptr [rax + 16], 6
  lea  rcx, [rip + template parameter object for fixed_string
  mov  qword ptr [rax + 24], rcx
  inc  dword ptr [rip + ut::v2_1_1::cfg<ut::v2_1_1::override>+52]
  mov  rax, qword ptr [rip + ut::cfg<ut::override>+136]
  mov  ecx, dword ptr [rax + 8]
  mov  edx, dword ptr [rax + 92]
  dec  edx
  mov  dword ptr [rax + 92], edx
  xor  esi, esi
  cmp  ecx, dword ptr [rax + 4*rdx + 28]
  sete sil
  inc  dword ptr [rax + 4*rsi + 16]
  xor  eax, eax
  ret
```

---

### API

```cpp
/**
 * Assert definition
 * @code
 * expect(42 == 42_i);
 * expect(42 == 42_i) << "log";
 * expect[42 == 42_i]; // fatal assertion, aborts further execution
 * @endcode
 */
inline constexpr struct {
  constexpr auto operator()(auto expr);
  constexpr auto operator[](auto expr);
} expect{};
```

```cpp
/**
 * Test suite definition
 * @code
 * suite test_suite = [] { ... };
 * @encode
 */
struct suite;
```

```cpp
/**
 * Test definition
 * @code
 * "foo"_test = []          { ... }; // compile-time and run-time
 * "foo"_test = [] mutable  { ... }; // run-time only
 * "foo"_test = [] constval { ... }; // compile-time only
 * @endcode
 */
template<fixed_string Str>
[[nodiscard]] constexpr auto operator""_test();
```

```cpp
/**
 * Compile time expression
 * @code
 * expect(constant<42_i == 42>); // forces compile-time evaluation and run-time check
 * auto i = 0;
 * expect(constant<i == 42_i>);  // compile-time error
 * @encode
 */
template<auto Expr> inline constexpr auto constant;
```

```cpp
/**
 * Allows mutating object (by default lambdas are immutable)
 * @code
 * "foo"_test = [] {
 *   int i = 0;
 *   "sub"_test = [i] {
 *     mut(i) = 42;
 *   };
 *   expect(i == 42_i);
 * };
 * @endcode
 */
template<class T> [[nodiscard]] constexpr auto& mut(const T&);
```

```cpp
template<class TLhs, class TRhs> struct eq;  // equal
template<class TLhs, class TRhs> struct neq; // not equal
template<class TLhs, class TRhs> struct gt;  // greater
template<class TLhs, class TRhs> struct ge;  // greater equal
template<class TLhs, class TRhs> struct lt;  // less
template<class TLhs, class TRhs> struct le;  // less equal
template<class TLhs, class TRhs> struct nt;  // not
```

```cpp
constexpr auto operator==(const auto& lhs, const auto& rhs) -> decltype(eq{lhs, rhs});
constexpr auto operator!=(const auto& lhs, const auto& rhs) -> decltype(neq{lhs, rhs});
constexpr auto operator> (const auto& lhs, const auto& rhs) -> decltype(gt{lhs, rhs});
constexpr auto operator>=(const auto& lhs, const auto& rhs) -> decltype(ge{lhs, rhs});
constexpr auto operator< (const auto& lhs, const auto& rhs) -> decltype(lt{lhs, rhs});
constexpr auto operator<=(const auto& lhs, const auto& rhs) -> decltype(le{lhs, rhs});
constexpr auto operator! (const auto& t)                    -> decltype(nt{t});
```

```cpp
struct _b;      // bool (true_b = _b{true}, false_b = _b{false})
struct _c;      // char
struct _sc;     // signed char
struct _s;      // short
struct _i;      // int
struct _l;      // long
struct _ll;     // long long
struct _u;      // unsigned
struct _uc;     // unsigned char
struct _us;     // unsigned short
struct _ul;     // unsigned long
struct _ull;    // unsigned long long
struct _f;      // float
struct _d;      // double
struct _ld;     // long double
struct _i8;     // int8_t
struct _i16;    // int16_t
struct _i32;    // int32_t
struct _i64;    // int64_t
struct _u8;     // uint8_t
struct _u16;    // uint16_t
struct _u32;    // uint32_t
struct _u64;    // uint64_t
struct _string; // const char*
```

```cpp
constexpr auto operator""_i(auto value)   -> decltype(_i(value));
constexpr auto operator""_s(auto value)   -> decltype(_s(value));
constexpr auto operator""_c(auto value)   -> decltype(_c(value));
constexpr auto operator""_sc(auto value)  -> decltype(_sc(value));
constexpr auto operator""_l(auto value)   -> decltype(_l(value));
constexpr auto operator""_ll(auto value)  -> decltype(_ll(value));
constexpr auto operator""_u(auto value)   -> decltype(_u(value));
constexpr auto operator""_uc(auto value)  -> decltype(_uc(value));
constexpr auto operator""_us(auto value)  -> decltype(_us(value));
constexpr auto operator""_ul(auto value)  -> decltype(_ul(value));
constexpr auto operator""_ull(auto value) -> decltype(_ull(value));
constexpr auto operator""_f(auto value)   -> decltype(_f(value));
constexpr auto operator""_d(auto value)   -> decltype(_d(value));
constexpr auto operator""_ld(auto value)  -> decltype(_ld(value));
constexpr auto operator""_i8(auto value)  -> decltype(_i8(value));
constexpr auto operator""_i16(auto value) -> decltype(_i16(value));
constexpr auto operator""_i32(auto value) -> decltype(_i32(value));
constexpr auto operator""_i64(auto value) -> decltype(_i64(value));
constexpr auto operator""_u8(auto value)  -> decltype(_u8(value));
constexpr auto operator""_u16(auto value) -> decltype(_u16(value));
constexpr auto operator""_u32(auto value) -> decltype(_u32(value));
constexpr auto operator""_u64(auto value) -> decltype(_u64(value));
```

```cpp
template<fixed_string Str>
[[nodiscard]] constexpr auto operator""_s() -> decltype(_string(Str));
```

> Configuration

```cpp
namespace events {
enum class mode {
  run_time,
  compile_time
};

template<mode Mode>
struct test_begin {
  const char* file_name{};
  int line{}; const char* name{};
};

template<mode Mode>
struct test_end {
  const char* file_name{};
  int line{};
  const char* name{};
  enum { FAILED, PASSED, COMPILE_TIME } result{};
};

template<class TExpr>
struct assert_pass {
  const char* file_name{};
  int line{};
  TExpr expr{};
};

template<class TExpr>
struct assert_fail {
  const char* file_name{};
  int line{};
  TExpr expr{};
};

struct fatal { };

template<class TMsg>
struct log {
  const TMsg& msg;
  bool result{};
};

struct summary {
  enum { FAILED, PASSED, COMPILE_TIME };
  unsigned asserts[2]{}; /* FAILED, PASSED */
  unsigned tests[3]{}; /* FAILED, PASSED, COMPILE_TIME */
};
} // namespace events
```

```cpp
struct outputter {
  template<events::mode Mode> constexpr auto on(const events::test_begin<Mode>&);
  constexpr auto on(const events::test_begin<events::mode::run_time>& event);
  template<events::mode Mode> constexpr auto on(const events::test_end<Mode>&);
  template<class TExpr> constexpr auto on(const events::assert_pass<TExpr>&);
  template<class TExpr> constexpr auto on(const events::assert_fail<TExpr>&);
  constexpr auto on(const events::fatal&);
  template<class TMsg> constexpr auto on(const events::log<TMsg>&);
  constexpr auto on(const events::summary& event);
};
```

```cpp
struct reporter {
  constexpr auto on(const events::test_begin<events::mode::run_time>&);
  constexpr auto on(const events::test_end<events::mode::run_time>&);
  constexpr auto on(const events::test_begin<events::mode::compile_time>&);
  constexpr auto on(const events::test_end<events::mode::compile_time>&);
  template<class TExpr> constexpr auto on(const events::assert_pass<TExpr>&);
  template<class TExpr> constexpr auto on(const events::assert_fail<TExpr>&);
  constexpr auto on(const events::fatal& event);
};
```

```cpp
struct runner {
  template<class Test> constexpr auto on(Test test) -> bool;
};
```

```cpp
/**
 * Customization point to override the default configuration
 * @code
 * template<class... Ts> auto ut::cfg<ut::override, Ts...> = my_config{};
 * @endcode
 */
struct override { }; /// to override configuration by users
struct default_cfg;  /// default configuration
template <class...> inline auto cfg = default_cfg{};
```

```cpp
#define UT_RUN_TIME_ONLY        // If defined tests will be executed
                                // at run-time + static_assert tests
#define UT_COMPILE_TIME_ONLY    // If defined only compile-time tests
                                // will be executed
```

---

### FAQ

- Can I disable running tests at compile-time for faster compilation times?

    > When `NTEST` is defined static_asserts tests wont be executed upon inclusion.
    Note: Use with caution as disabling tests means that there are no guarantees upon inclusion that the given compiler/env combination works as expected.

- How to integrate with CMake/CPM?

    ```
    CPMAddPackage(
      Name ut
      GITHUB_REPOSITORY qlibs/ut
      GIT_TAG v2.1.2
    )
    add_library(ut INTERFACE)
    target_include_directories(ut SYSTEM INTERFACE ${ut_SOURCE_DIR})
    add_library(ut::ut ALIAS ut)
    ```

    ```
    target_link_libraries(${PROJECT_NAME} ut::ut);
    ```

- Similar projects?
    > [ut](https://github.com/boost-ext/ut), [catch2](https://github.com/catchorg/Catch2), [googletest](https://github.com/google/googletest), [gunit](https://github.com/cpp-testing/GUnit), [boost.test](https://www.boost.org/doc/libs/latest/libs/test/doc/html/index.html)
---
