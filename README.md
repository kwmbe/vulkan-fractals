# vulkan-fractals
Clone of my [vulkan-test](https://github.com/kwmbe/vulkan-test) repo for trying to visualise fractals with vulkan.  
Currently trying to visualise the mandelbrot fractal, allowing near infinite zoom making use of [perturbation theory](https://en.wikipedia.org/wiki/Perturbation_theory).

## Running the application
First build the application with:
```
cmake -B ./build
cmake --build ./build
```
Now you can execute the application with `build/Fractals`

## Controls
Click and drag to pan around.  
Scroll for zooming in and out.

## Gallery

![Mandelbrot fractal](./images/mandelbrot.png)
![Mandelbrot closeup](./images/closeup.png)
