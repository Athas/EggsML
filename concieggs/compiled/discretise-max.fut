-- Summarises an n-element input in k bins, with each of the k bins
-- containing the maximum of the input in that span.
--
-- Produces relative (integral) frequencies from 0 to 8.
let main [n] (k: i64) (samples: [n]i32) =
  let bin_size = f32.i64 n / f32.i64 k
  let index i = i64.f32 (f32.i64 i / bin_size)
  let max = i32.maximum samples
  let relative x = i32.f32 ((f32.i32 x / f32.i32 max) * 8)
  in reduce_by_index (replicate k 0) i32.max i32.highest
                     (map index (iota n)) samples
     |> map relative
