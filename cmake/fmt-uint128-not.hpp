// Force-included when compiling the bundled fmt; see cmake/load_fmt_spdlog.cmake for why.

#include <fmt/format.h>

FMT_BEGIN_NAMESPACE
namespace detail {

constexpr auto operator~(const uint128& n) -> uint128 {
    return {~n.high(), ~n.low()};
}

}  // namespace detail
FMT_END_NAMESPACE
