def foo()
    arr1 = [0,1,2]
    arr2 = [3,4,5]
    arr3 = [6,7,8]
    arr = [arr1, arr2, arr3]
    arr.each do |row|
        row.each do |value|
            yield(value)
        end
    end
end 

foo() do |x|
    puts("x: #{x}")
end
