fn main() {
    let a = crossbeam_utils::atomic::AtomicCell::new(1u8);

    println!("{:?}", a.fetch_add(2u8));
}
