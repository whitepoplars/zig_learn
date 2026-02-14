// BWO出品！！！！

const std = @import("std");

//zig接口的运作方式：接口是一个结构体，也是一个类型，通过一个结构体实现接口的所有功能。
//它定义了接口名字（就是这个结构体名），列出了接口需要实现的函数列表，定义了如何把另一个结构体指针转化为这个接口结构体。
//这个结构体有两个字段。这两个字段都是指针。
//一个指针可以指向任何对象。
//另一个指针指向vtab,而vtab里面，有数个函数指针。
const Shape = struct {
    ptr: *anyopaque,
    vtab: *const VTab,

    pub const VTab = struct { //vtab的字段是多个函数指针,这里只放两个。
        draw: *const fn (ptr: *anyopaque) void,
        move: *const fn (ptr: *anyopaque, dx: i32, dy: i32) void,
    };

    //接口实例通过vtab调用函数
    pub fn draw(self: Shape) void {
        self.vtab.draw(self.ptr);
    }
    pub fn move(self: Shape, dx: i32, dy: i32) void {
        self.vtab.move(self.ptr, dx, dy);
    }

    // form函数：传入一个指向struct实例的指针，返回Shape实例。完成“接口的构造“。
    // obj的类型是anytype，因为这样才能接受任意指针。实际用的时候，必须传入一个指向struct实例的指针，否则报错。
    pub fn form(obj: anytype) Shape {
        const PtrT = @TypeOf(obj); //获得参数的实例类型
        const info = @typeInfo(PtrT);
        comptime {
            if (info != .pointer) { //必须是指针
                @compileError("Shape.init() 需要一个指针，但你传入的是：" ++ @typeName(PtrT));
            }
            if (info.pointer.size != .one) { //必须是单项指针
                @compileError("只接受单个对象的指针 (*T 或 *const T)，不支持切片、多指针等：" ++ @typeName(PtrT));
            }
            const child_info = @typeInfo(info.pointer.child);
            if (child_info != .@"struct") { //指针必须指向结构体
                @compileError("指针必须指向一个 struct，实际指向的是：" ++ @typeName(info.pointer.child));
            }
            //还可以增加其他检查，比如检查是否实现了所有接口函数。
        }

        const impl = struct {
            fn draw(ptr: *anyopaque) void {
                //我们给draw传入一个指向了实现了draw方法的结构体的指针，我们用*anyopaque类型（它可以兼容所有指针）接受这个指针。
                //ptr是一个*anyopaque类型，anyopaque这个类型不包含任何类型信息，编译器根本不知道ptr可以做什么
                //通过alignCast调整对齐，再通过ptrCast调整类型，现在self是一个被赋予了类型信息的指针
                //通过这个被还原了类型信息的指针，我们就可以调用实际的函数了
                const self: @TypeOf(obj) = @ptrCast(@alignCast(ptr));
                self.draw();
            }
            fn move(ptr: *anyopaque, dx: i32, dy: i32) void {
                const self: @TypeOf(obj) = @ptrCast(@alignCast(ptr));
                self.move(dx, dy);
            }
        };

        //终于，返回Shape实例
        return .{
            .ptr = obj,
            .vtab = &.{
                .draw = &impl.draw, //把实际函数地址赋值过去
                .move = &impl.move,
            },
        };
    }
};

//实例用法：

// 两种不同的具体形状（完全不需要知道 Shape 的存在）

const Circle = struct {
    x: i32,
    y: i32,
    r: u32,

    pub fn draw(self: *const Circle) void {
        std.debug.print("Circle at ({d},{d}) r={d}  ○\n", .{ self.x, self.y, self.r });
    }

    pub fn move(self: *Circle, dx: i32, dy: i32) void {
        self.x += dx;
        self.y += dy;
    }
};

const Rect = struct {
    x: i32,
    y: i32,
    w: u32,
    h: u32,

    pub fn draw(self: *const Rect) void {
        std.debug.print("Rect  at ({d},{d}) {d}×{d}  ▭\n", .{ self.x, self.y, self.w, self.h });
    }

    pub fn move(self: *Rect, dx: i32, dy: i32) void {
        self.x += dx;
        self.y += dy;
    }
};

pub fn main() !void {

    // 1. 创建具体对象（堆上或栈上都可以）
    var c = Circle{ .x = 10, .y = 20, .r = 5 };
    var r = Rect{ .x = 30, .y = 40, .w = 60, .h = 25 };

    // 2. 包装成统一的 Shape 接口
    const shapes = [_]Shape{
        Shape.form(&c),
        Shape.form(&r),
    };

    // 3. 多态调用（完全不知道具体类型）
    for (shapes) |s| {
        s.draw();
        s.move(100, 50);
        s.draw(); // 位置变了
    }

    // 输出类似：
    // Circle at (10,20) r=5  ○
    // Circle at (110,70) r=5  ○
    // Rect  at (30,40) 60×25  ▭
    // Rect  at (130,90) 60×25  ▭
}
