!>----------------------------------------------------------
!!
!! This module provides a wrapper to call various microphysics models
!! It sets up variables specific to the physics package to be used including 
!! history variables not currently stored in the domain level data structure
!!
!! The main entry point to the code is mp(domain,options,dt)
!!
!! Call tree graph :
!!	mp_init->[ external initialization routines]
!!	mp->[	external microphysics routines]
!!  mp_finish
!! 
!! High level routine descriptions / purpose
!!   mp_init    		- allocates module data and initializes physics package
!!   mp           		- sets up and calls main physics package
!!   mp_finish			- deallocates module memory, place to do the same for physics
!! 
!! Inputs: domain, options, dt
!! 		domain,options	= as defined in data_structures
!! 		dt 				= time step (seconds)
!!
!! Author : Ethan Gutmann (gutmann@ucar.edu)
!!
!!----------------------------------------------------------
module microphysics
	use data_structures
	use module_mp_thompson, only: mp_gt_driver,thompson_init
	use module_mp_simple, only:mp_simple_driver
	implicit none
! 	these are now defined in data_structures.f90
! 	real, parameter :: LH_vaporization=2260000.0 ! J/kg
! 	real, parameter :: R=287.058 ! J/(kg K) specific gas constant for air
! 	real, parameter :: cp = 1012.0 ! specific heat capacity of moist STP air? J/kg/K
! 	real, parameter :: g=9.81 ! gravity m/s^2

	real,allocatable,dimension(:,:,:)::SR

contains
	subroutine mp_init(options)
		implicit none
		type(options_type), intent(in)::options
                real:: Nt_c,am_s,rho_g,av_s,bv_s,fv_s,av_g,bv_g,Ef_rs,Ef_rg  ! ++ trude
		if (options%physics%microphysics==1) then
                ! ++ trude
                        Nt_c = options%mp_options%Nt_c
                        am_s = options%mp_options%am_s
                        rho_g = options%mp_options%rho_g
                        av_s = options%mp_options%av_s
                        bv_s = options%mp_options%bv_s
                        fv_s = options%mp_options%fv_s
                        av_g = options%mp_options%av_g
                        bv_g = options%mp_options%bv_g
                        Ef_rs = options%mp_options%Ef_rs
                        Ef_rg = options%mp_options%Ef_rg
 			call thompson_init(Nt_c, am_s,rho_g,av_s,bv_s,fv_s,av_g,bv_g,Ef_rs,Ef_rg)
!foo 			call thompson_init(options%mp_options)
  
               ! -- trude
		endif
	end subroutine mp_init
	
	subroutine mp(domain,options,dt_in)
		implicit none
		type(domain_type),intent(inout)::domain
		type(options_type),intent(in)::options
		real,intent(in)::dt_in
                real:: Nt_c, TNO, rho_g,av_s,bv_s,fv_s,av_g,bv_g,Ef_si,Ef_ri  ! ++ trude
		integer ::ids,ide,jds,jde,kds,kde,itimestep=1
		integer ::its,ite,jts,jte,kts,kte
		
		ids=1
		ide=size(domain%qv,1)
		kds=1
		kde=size(domain%qv,2)
		jds=1
		jde=size(domain%qv,3)

		if (.not.allocated(SR)) then
			allocate(SR(ids:ide,kds:kde,jds:jde))
	! 		snow rain ratio
			SR=0
		endif
		if (options%physics%microphysics==1) then
! ++ trude
                        Nt_c = options%mp_options%Nt_c  
                        TNO = options%mp_options%TNO
                        rho_g = options%mp_options%rho_g
                        av_s = options%mp_options%av_s
                        bv_s = options%mp_options%bv_s
                        fv_s = options%mp_options%fv_s
                        av_g = options%mp_options%av_g
                        bv_g = options%mp_options%bv_g
                        Ef_si = options%mp_options%Ef_si
                        Ef_ri = options%mp_options%Ef_ri
! --  trude
 			kts=kds;kte=kde
			if (options%ideal) then
				! for ideal runs process the boundaries as well to be consistent with WRF
				its=ids;ite=ide
				jts=jds;jte=jde
			else
				its=ids+1;ite=ide-1
				jts=jds+1;jte=jde-1
			endif

			call mp_gt_driver(domain%qv, domain%cloud, domain%qrain, domain%ice, &
			                domain%qsnow, domain%qgrau, domain%nice, domain%nrain, &
							domain%th, domain%pii, domain%p, domain%dz, dt_in, itimestep, &
							domain%rain, domain%rain, &
							domain%snow, domain%snow, &
							domain%graupel, domain%graupel, &
							SR, &
                                                        Nt_c, TNO, rho_g,av_s,bv_s,fv_s,av_g,bv_g, Ef_si,Ef_ri,&  ! trude added
							ids,ide, jds,jde, kds,kde, &    ! domain dims
							ids,ide, jds,jde, kds,kde, &    ! memory dims
							its,ite, jts,jte, kts,kte)      ! tile dims
		elseif (options%physics%microphysics==2) then
			call mp_simple_driver(domain%p,domain%th,domain%pii,domain%rho,domain%qv,domain%cloud, &
							domain%qrain,domain%qsnow,domain%rain,domain%snow,&
							dt_in,domain%dz,ide,jde,kde)
		endif
						
	end subroutine mp
	
	subroutine mp_finish()
		implicit none
		if (allocated(SR)) then
			deallocate(SR)
		endif
	end subroutine mp_finish
end module microphysics
